"""Three-way merge for UTF-16 text files that git treats as binary.

Several Parallax Lua sources are UTF-16 with a byte-order mark (GPU
Temperature.lua, Media's MediaHeader.lua, QueueReader.lua, SourceReader.lua),
some with mixed CRLF/LF line endings. Their NUL bytes make git treat them as
binary, so a cherry-pick or revert that touches one of them stops with a
binary conflict whenever the target's copy differs from the commit's parent
(or, for a revert, from the commit itself).

This helper resolves such a conflict the way git would for a text file: it
reads the three index stages (1 base, 2 ours, 3 theirs), decodes them,
runs `git merge-file` on the decoded text, and re-encodes the result with the
original byte-order mark. Line endings are never normalized: each line keeps
its own CRLF or LF, so a mixed-ending file stays byte-for-byte as mixed as
before. It refuses, and changes nothing, when it cannot be sure:

  * a stage is missing (add/delete or modify/delete conflict);
  * a stage has no UTF-16 byte-order mark, or the stages disagree on it;
  * a stage does not round-trip byte for byte through decode/encode;
  * the text contains NUL characters (git merge-file would call it binary);
  * git merge-file fails.

A merge with conflicts is written to the working tree with the usual
conflict markers (in the file's own encoding) for inspection, but is never
added to the index, exactly like an ordinary text conflict.

Commands (run from anywhere; --repo names the work tree):

  resolve [--repo DIR] [--no-add] PATH...
      Resolve the conflicted UTF-16 paths from their index stages. Prints one
      JSON object per path. Exit 0 when every path merged cleanly (and was
      added unless --no-add), 1 when any merge had conflicts, 2 when any path
      was refused.
  merge OURS BASE THEIRS -o OUT
      Merge three files directly. Exit codes as above.
  probe [--repo DIR] PATH...
      Report each conflicted path's stage encodings without writing anything.

Requires git on PATH (or --git). Uses only the Python standard library.
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile

# Order matters: a UTF-32LE BOM starts with the UTF-16LE one.
UTF32_BOMS = (b'\xff\xfe\x00\x00', b'\x00\x00\xfe\xff')
UTF16_BOMS = ((b'\xff\xfe', 'utf-16-le'), (b'\xfe\xff', 'utf-16-be'))

EXIT_CLEAN = 0
EXIT_CONFLICT = 1
EXIT_REFUSED = 2


class Refused(Exception):
    """The helper cannot merge this input without guessing."""


class Utf16Text(object):
    def __init__(self, bom, codec, text):
        self.bom = bom
        self.codec = codec
        self.text = text

    def encode(self, text=None):
        body = (self.text if text is None else text).encode(self.codec, 'surrogatepass')
        return self.bom + body


def detect_bom(raw):
    """Return (bom, codec) for a UTF-16 byte-order mark, else (None, None)."""
    for bom in UTF32_BOMS:
        if raw.startswith(bom):
            return None, None
    for bom, codec in UTF16_BOMS:
        if raw.startswith(bom):
            return bom, codec
    return None, None


def decode(raw, label='input'):
    """Decode UTF-16 bytes with a BOM, proving the bytes round-trip exactly."""
    bom, codec = detect_bom(raw)
    if bom is None:
        raise Refused('%s has no UTF-16 byte-order mark' % label)
    body = raw[len(bom):]
    if len(body) % 2:
        raise Refused('%s has an odd number of UTF-16 bytes' % label)
    text = body.decode(codec, 'surrogatepass')
    if text.encode(codec, 'surrogatepass') != body:
        raise Refused('%s does not round-trip through %s' % (label, codec))
    if '\x00' in text:
        raise Refused('%s contains NUL characters' % label)
    return Utf16Text(bom, codec, text)


def line_endings(text):
    """Count CRLF, bare LF and bare CR line endings (for reports and tests)."""
    crlf = text.count('\r\n')
    return {'crlf': crlf, 'lf': text.count('\n') - crlf, 'cr': text.count('\r') - crlf}


def merge_text(ours, base, theirs, labels=('ours', 'base', 'theirs'), git='git'):
    """Merge decoded texts with git merge-file. Returns (text, conflicts)."""
    folder = tempfile.mkdtemp(prefix='pxu16')
    try:
        paths = []
        for name, text in (('ours', ours), ('base', base), ('theirs', theirs)):
            path = os.path.join(folder, name)
            with open(path, 'wb') as handle:
                handle.write(text.encode('utf-8', 'surrogatepass'))
            paths.append(path)
        # Without -p, merge-file writes the result over the first file. That
        # avoids any console text-mode translation of stdout.
        command = [git, 'merge-file']
        for label in labels:
            command += ['-L', label]
        result = subprocess.run(command + paths, capture_output=True)
        if result.returncode < 0 or result.returncode > 127:
            raise Refused('git merge-file failed (%d): %s' % (
                result.returncode, result.stderr.decode('utf-8', 'replace').strip()))
        with open(paths[0], 'rb') as handle:
            merged = handle.read().decode('utf-8', 'surrogatepass')
        return merged, result.returncode
    finally:
        for name in os.listdir(folder):
            os.remove(os.path.join(folder, name))
        os.rmdir(folder)


def merge_bytes(ours_raw, base_raw, theirs_raw, labels=('ours', 'base', 'theirs'), git='git'):
    """Merge three UTF-16 blobs. Returns (bytes, conflicts, info)."""
    ours = decode(ours_raw, 'ours (stage 2)')
    base = decode(base_raw, 'base (stage 1)')
    theirs = decode(theirs_raw, 'theirs (stage 3)')
    if not (ours.bom == base.bom == theirs.bom):
        raise Refused('the stages disagree on the byte-order mark (%s / %s / %s)' % (
            ours.codec, base.codec, theirs.codec))
    merged, conflicts = merge_text(ours.text, base.text, theirs.text, labels, git)
    data = ours.encode(merged)
    if decode(data, 'merge result').text != merged:
        raise Refused('the merge result does not round-trip')
    info = {'codec': ours.codec, 'endings': line_endings(merged)}
    return data, conflicts, info


def run_git(repo, args, git='git', check=True):
    result = subprocess.run([git, '-C', repo] + args, capture_output=True)
    if check and result.returncode != 0:
        raise Refused('git %s failed: %s' % (' '.join(args), result.stderr.decode('utf-8', 'replace').strip()))
    return result


def literal(path):
    return ':(literal)' + path


def unmerged_stages(repo, path, git='git'):
    """Map stage number -> blob id for one unmerged path."""
    out = run_git(repo, ['ls-files', '-u', '-z', '--', literal(path)], git).stdout.decode('utf-8')
    stages = {}
    for record in out.split('\0'):
        if not record:
            continue
        meta, name = record.split('\t', 1)
        if name.replace('\\', '/') != path.replace('\\', '/'):
            continue
        _mode, blob, stage = meta.split(' ')
        stages[int(stage)] = blob
    return stages


def read_blob(repo, blob, git='git'):
    return run_git(repo, ['cat-file', 'blob', blob], git).stdout


def repo_path(repo, path, git='git'):
    """Return (work tree root, repo-relative path). A relative PATH is relative
    to the work tree root, as in git's index; an absolute one must lie inside it."""
    top = run_git(repo, ['rev-parse', '--show-toplevel'], git).stdout.decode('utf-8').strip()
    candidate = path if os.path.isabs(path) else os.path.join(top, path)
    relative = os.path.relpath(os.path.abspath(candidate), os.path.abspath(top))
    if relative == '.' or relative.startswith('..'):
        raise Refused('%s is outside the work tree %s' % (path, top))
    return top, relative.replace('\\', '/')


def probe_path(repo, path, git='git'):
    top, relative = repo_path(repo, path, git)
    stages = unmerged_stages(top, relative, git)
    report = {'path': relative, 'stages': {}}
    for stage in (1, 2, 3):
        if stage not in stages:
            report['stages'][str(stage)] = None
            continue
        bom, codec = detect_bom(read_blob(top, stages[stage], git))
        report['stages'][str(stage)] = codec or 'not-utf16'
    report['utf16'] = all(value not in (None, 'not-utf16') for value in report['stages'].values())
    return report


def resolve_path(repo, path, add=True, git='git'):
    """Resolve one conflicted path. Returns a report dict with 'status'."""
    top, relative = repo_path(repo, path, git)
    report = {'path': relative}
    stages = unmerged_stages(top, relative, git)
    missing = [stage for stage in (1, 2, 3) if stage not in stages]
    if not stages:
        raise Refused('%s is not an unmerged path' % relative)
    if missing:
        raise Refused('%s lacks index stage(s) %s (add/delete conflict)' % (
            relative, ', '.join(str(stage) for stage in missing)))
    data, conflicts, info = merge_bytes(
        read_blob(top, stages[2], git), read_blob(top, stages[1], git), read_blob(top, stages[3], git),
        labels=('ours', 'base', 'theirs'), git=git)
    report.update(info)
    target = os.path.join(top, relative.replace('/', os.sep))
    with open(target, 'wb') as handle:
        handle.write(data)
    report['conflicts'] = conflicts
    if conflicts:
        report['status'] = 'conflict'
        return report
    if add:
        run_git(top, ['add', '--', literal(relative)], git)
    report['status'] = 'resolved'
    return report


def command_resolve(args):
    worst = EXIT_CLEAN
    for path in args.paths:
        try:
            report = resolve_path(args.repo, path, add=not args.no_add, git=args.git)
            if report['status'] == 'conflict':
                worst = max(worst, EXIT_CONFLICT)
        except Refused as error:
            report = {'path': path, 'status': 'refused', 'reason': str(error)}
            worst = EXIT_REFUSED
        print(json.dumps(report, sort_keys=True))
    return worst


def command_probe(args):
    worst = EXIT_CLEAN
    for path in args.paths:
        try:
            report = probe_path(args.repo, path, git=args.git)
        except Refused as error:
            report = {'path': path, 'status': 'refused', 'reason': str(error)}
            worst = EXIT_REFUSED
        print(json.dumps(report, sort_keys=True))
    return worst


def command_merge(args):
    def read(path):
        with open(path, 'rb') as handle:
            return handle.read()
    try:
        data, conflicts, info = merge_bytes(read(args.ours), read(args.base), read(args.theirs), git=args.git)
    except Refused as error:
        print(json.dumps({'status': 'refused', 'reason': str(error)}))
        return EXIT_REFUSED
    with open(args.output, 'wb') as handle:
        handle.write(data)
    info.update({'status': 'conflict' if conflicts else 'resolved', 'conflicts': conflicts, 'path': args.output})
    print(json.dumps(info, sort_keys=True))
    return EXIT_CONFLICT if conflicts else EXIT_CLEAN


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('--git', default='git', help='git executable (default: git on PATH)')
    commands = parser.add_subparsers(dest='command')
    resolve = commands.add_parser('resolve')
    resolve.add_argument('--repo', default='.')
    resolve.add_argument('--no-add', action='store_true')
    resolve.add_argument('paths', nargs='+')
    probe = commands.add_parser('probe')
    probe.add_argument('--repo', default='.')
    probe.add_argument('paths', nargs='+')
    merge = commands.add_parser('merge')
    merge.add_argument('ours')
    merge.add_argument('base')
    merge.add_argument('theirs')
    merge.add_argument('-o', '--output', required=True)
    args = parser.parse_args(argv)
    if args.command == 'resolve':
        return command_resolve(args)
    if args.command == 'probe':
        return command_probe(args)
    if args.command == 'merge':
        return command_merge(args)
    parser.print_help()
    return EXIT_REFUSED


if __name__ == '__main__':
    sys.exit(main())
