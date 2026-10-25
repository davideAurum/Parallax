"""Tests for tools/Merge-Utf16Text.py.

Run: python -I tools/tests/test_merge_utf16.py
Creates scratch git repositories under the system temp folder and removes
them afterwards. Never touches the Parallax repository itself.
"""
import importlib.util
import json
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest

TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HELPER = os.path.join(TOOLS, 'Merge-Utf16Text.py')
spec = importlib.util.spec_from_file_location('merge_utf16', HELPER)
merge_utf16 = importlib.util.module_from_spec(spec)
spec.loader.exec_module(merge_utf16)

LE = b'\xff\xfe'
BE = b'\xfe\xff'


def utf16le(text):
    return LE + text.encode('utf-16-le')


def utf16be(text):
    return BE + text.encode('utf-16-be')


def mixed_lines(count=40, changed=None):
    """A Lua-like text whose odd lines end in LF and even lines in CRLF."""
    changed = changed or {}
    lines = []
    for index in range(count):
        body = changed.get(index, 'local value%02d = %d -- été' % (index, index))
        lines.append(body + ('\n' if index % 2 else '\r\n'))
    return ''.join(lines)


def remove_tree(path):
    def retry(function, target, _info):
        os.chmod(target, stat.S_IWRITE)
        function(target)
    if sys.version_info >= (3, 12):
        shutil.rmtree(path, onexc=retry)
    else:
        shutil.rmtree(path, onerror=retry)


class DecodeTests(unittest.TestCase):
    def test_round_trip_keeps_bom_and_mixed_endings(self):
        text = mixed_lines(7)
        decoded = merge_utf16.decode(utf16le(text))
        self.assertEqual(decoded.codec, 'utf-16-le')
        self.assertEqual(decoded.text, text)
        self.assertEqual(decoded.encode(), utf16le(text))
        self.assertEqual(merge_utf16.line_endings(text), {'crlf': 4, 'lf': 3, 'cr': 0})

    def test_big_endian(self):
        decoded = merge_utf16.decode(utf16be('a\r\nb\n'))
        self.assertEqual(decoded.codec, 'utf-16-be')
        self.assertEqual(decoded.encode(), utf16be('a\r\nb\n'))

    def test_lone_surrogate_round_trips(self):
        raw = LE + b'\x00\xd8' + 'x\n'.encode('utf-16-le')
        self.assertEqual(merge_utf16.decode(raw).encode(), raw)

    def test_refusals(self):
        for raw, reason in (
            (b'plain ascii\n', 'byte-order mark'),
            (b'\xef\xbb\xbfutf8\n', 'byte-order mark'),
            (b'\xff\xfe\x00\x00' + 'x'.encode('utf-32-le'), 'byte-order mark'),
            (LE + b'a\x00b', 'odd number'),
            (utf16le('a\x00b\n'), 'NUL'),
        ):
            with self.assertRaises(merge_utf16.Refused) as caught:
                merge_utf16.decode(raw)
            self.assertIn(reason, str(caught.exception))


class MergeBytesTests(unittest.TestCase):
    def test_clean_merge_is_byte_exact_with_mixed_endings(self):
        base = mixed_lines()
        ours = mixed_lines(changed={2: 'local top = "ours"'})
        theirs = mixed_lines(changed={37: 'local bottom = [[theirs]]'})
        expected = mixed_lines(changed={2: 'local top = "ours"', 37: 'local bottom = [[theirs]]'})
        data, conflicts, info = merge_utf16.merge_bytes(utf16le(ours), utf16le(base), utf16le(theirs))
        self.assertEqual(conflicts, 0)
        self.assertEqual(data, utf16le(expected))
        self.assertEqual(info['endings'], {'crlf': 20, 'lf': 20, 'cr': 0})

    def test_line_ending_change_is_merged_not_normalized(self):
        base = 'a\r\nb\r\nc\r\nd\r\ne\r\nf\r\n'
        ours = 'a\nb\r\nc\r\nd\r\ne\r\nf\r\n'      # first line becomes LF
        theirs = 'a\r\nb\r\nc\r\nd\r\ne\r\nF\r\n'  # last line edited
        data, conflicts, _ = merge_utf16.merge_bytes(utf16le(ours), utf16le(base), utf16le(theirs))
        self.assertEqual(conflicts, 0)
        self.assertEqual(data, utf16le('a\nb\r\nc\r\nd\r\ne\r\nF\r\n'))

    def test_big_endian_merge(self):
        base = 'one\ntwo\nthree\nfour\nfive\nsix\n'
        data, conflicts, info = merge_utf16.merge_bytes(
            utf16be(base.replace('one', 'ONE')), utf16be(base), utf16be(base.replace('six', 'SIX')))
        self.assertEqual(conflicts, 0)
        self.assertEqual(info['codec'], 'utf-16-be')
        self.assertEqual(data, utf16be('ONE\ntwo\nthree\nfour\nfive\nSIX\n'))

    def test_overlapping_edits_conflict(self):
        base = mixed_lines()
        data, conflicts, _ = merge_utf16.merge_bytes(
            utf16le(mixed_lines(changed={5: 'ours'})), utf16le(base), utf16le(mixed_lines(changed={5: 'theirs'})))
        self.assertEqual(conflicts, 1)
        text = merge_utf16.decode(data).text
        self.assertIn('<<<<<<< ours', text)
        self.assertIn('>>>>>>> theirs', text)

    def test_bom_mismatch_refused(self):
        with self.assertRaises(merge_utf16.Refused) as caught:
            merge_utf16.merge_bytes(utf16le('a\n'), utf16be('a\n'), utf16le('b\n'))
        self.assertIn('disagree', str(caught.exception))


class RepositoryTests(unittest.TestCase):
    """Cherry-pick and revert paths in a scratch repository."""

    def setUp(self):
        self.root = tempfile.mkdtemp(prefix='pxu')
        self.git('init', '-q', '-b', 'main')
        for key, value in (('user.name', 'Fixture'), ('user.email', 'fixture@localhost.invalid'),
                           ('core.autocrlf', 'false'), ('commit.gpgsign', 'false')):
            self.git('config', key, value)
        self.path = 'Skins/Mod/Controller.lua'
        self.write(self.path, utf16le(mixed_lines()))
        self.write('notes.txt', b'plain\n')
        self.git('add', '-A')
        self.git('commit', '-q', '-m', 'base')
        self.base = self.rev('HEAD')
        self.write(self.path, utf16le(mixed_lines(changed={1: 'local a = 1'})))
        self.git('commit', '-q', '-am', 'fix A')
        self.fix_a = self.rev('HEAD')
        self.write(self.path, utf16le(mixed_lines(changed={1: 'local a = 1', 38: 'local b = 2'})))
        self.git('commit', '-q', '-am', 'fix B')
        self.fix_b = self.rev('HEAD')

    def tearDown(self):
        remove_tree(self.root)

    def git(self, *args, check=True):
        result = subprocess.run(['git', '-C', self.root] + list(args), capture_output=True)
        if check and result.returncode != 0:
            raise AssertionError('git %s: %s' % (args, result.stderr.decode('utf-8', 'replace')))
        return result

    def rev(self, name):
        return self.git('rev-parse', name).stdout.decode().strip()

    def write(self, relative, data):
        target = os.path.join(self.root, relative.replace('/', os.sep))
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, 'wb') as handle:
            handle.write(data)

    def read(self, relative):
        with open(os.path.join(self.root, relative.replace('/', os.sep)), 'rb') as handle:
            return handle.read()

    def unmerged(self):
        return self.git('diff', '--name-only', '--diff-filter=U').stdout.decode().split()

    def cli(self, *args):
        result = subprocess.run([sys.executable, '-I', HELPER] + list(args), capture_output=True)
        lines = [json.loads(line) for line in result.stdout.decode('utf-8').splitlines() if line.strip()]
        return result.returncode, lines

    def test_cherry_pick_without_its_parent_change(self):
        self.git('checkout', '-q', '--detach', self.base)
        picked = self.git('cherry-pick', '--no-commit', self.fix_b, check=False)
        self.assertNotEqual(picked.returncode, 0, 'git must stop on the binary conflict')
        self.assertEqual(self.unmerged(), [self.path])
        code, reports = self.cli('resolve', '--repo', self.root, self.path)
        self.assertEqual(code, 0, reports)
        self.assertEqual(reports[0]['status'], 'resolved')
        self.assertEqual(reports[0]['endings'], {'crlf': 20, 'lf': 20, 'cr': 0})
        self.assertEqual(self.unmerged(), [])
        expected = utf16le(mixed_lines(changed={38: 'local b = 2'}))
        self.assertEqual(self.read(self.path), expected)
        staged = self.git('show', ':' + self.path).stdout
        self.assertEqual(staged, expected, 'the index must hold the merged bytes')

    def test_revert_from_a_later_tip(self):
        self.git('checkout', '-q', '--detach', self.fix_b)
        reverted = self.git('revert', '--no-commit', self.fix_a, check=False)
        self.assertNotEqual(reverted.returncode, 0)
        code, reports = self.cli('resolve', '--repo', self.root, self.path)
        self.assertEqual(code, 0, reports)
        self.assertEqual(self.read(self.path), utf16le(mixed_lines(changed={38: 'local b = 2'})))

    def test_conflicting_change_is_left_unmerged(self):
        self.write(self.path, utf16le(mixed_lines(changed={38: 'local b = 99'})))
        self.git('commit', '-q', '-am', 'competing edit')
        picked = self.git('cherry-pick', '--no-commit', self.fix_b, check=False)
        self.assertNotEqual(picked.returncode, 0)
        code, reports = self.cli('resolve', '--repo', self.root, self.path)
        self.assertEqual(code, 1)
        self.assertEqual(reports[0]['status'], 'conflict')
        self.assertEqual(self.unmerged(), [self.path], 'a conflicted merge must not be added')
        text = merge_utf16.decode(self.read(self.path)).text
        self.assertIn('<<<<<<< ours', text)

    def test_modify_delete_is_refused(self):
        self.git('rm', '-q', self.path)
        self.git('commit', '-q', '-m', 'delete')
        picked = self.git('cherry-pick', '--no-commit', self.fix_b, check=False)
        self.assertNotEqual(picked.returncode, 0)
        code, reports = self.cli('resolve', '--repo', self.root, self.path)
        self.assertEqual(code, 2)
        self.assertEqual(reports[0]['status'], 'refused')
        self.assertIn('stage', reports[0]['reason'])

    def test_probe_and_non_utf16_refusal(self):
        self.git('checkout', '-q', '--detach', self.base)
        self.write('notes.txt', b'other edit\n')
        self.git('commit', '-q', '-am', 'edit notes on one line of work')
        other = self.rev('HEAD')
        self.git('checkout', '-q', '--detach', self.base)
        self.write('notes.txt', b'base edit\n')
        self.git('commit', '-q', '-am', 'edit notes on another')
        picked = self.git('cherry-pick', '--no-commit', other, check=False)
        self.assertNotEqual(picked.returncode, 0)
        conflicted = self.unmerged()
        self.assertIn('notes.txt', conflicted)
        code, reports = self.cli('probe', '--repo', self.root, *conflicted)
        self.assertEqual(code, 0)
        by_path = {report['path']: report for report in reports}
        self.assertFalse(by_path['notes.txt']['utf16'])
        code, reports = self.cli('resolve', '--repo', self.root, 'notes.txt')
        self.assertEqual(code, 2)
        self.assertIn('byte-order mark', reports[0]['reason'])
        self.assertIn('notes.txt', self.unmerged(), 'a refused path must stay unmerged')

    def test_path_outside_work_tree_refused(self):
        code, reports = self.cli('resolve', '--repo', self.root, os.path.dirname(self.root))
        self.assertEqual(code, 2)
        self.assertIn('outside', reports[0]['reason'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
