"""Read-only server for tools/perf-dashboard.html.

Serves only the dashboard page, the benchmark/trace result folders and the
bundled fonts - nothing else in the repository - with GET/HEAD only. Every path
sits behind a random token kept in build/perf-dashboard/token.txt, so a link is
needed even on a trusted network. Loopback clients get a redirect from "/" to the
tokenised page (for the desktop Browser pane); other clients get 404 there.

With --tailscale it also listens on this machine's Tailscale IPv4 address, so a
phone on the same tailnet can open the dashboard. It never binds 0.0.0.0, so
Public/LAN interfaces are not exposed.

    python tools/Serve-PerfDashboard.py --port 8765 --tailscale
"""

import argparse
import html
import json
import os
import posixpath
import secrets
import shutil
import subprocess
import sys
import threading
import urllib.parse
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PAGE = "tools/perf-dashboard.html"
LISTED_DIRS = {
    "build/perf-benchmark": (".json",),
    "build/perf-trace": (".csv", ".json"),
}
FONT_DIR = "Skins/Parallax/@Resources/Fonts"
TYPES = {
    ".html": "text/html; charset=utf-8",
    ".json": "application/json; charset=utf-8",
    ".csv": "text/csv; charset=utf-8",
    ".ttf": "font/ttf",
}
TOKEN_FILE = ROOT / "build" / "perf-dashboard" / "token.txt"


def load_token():
    TOKEN_FILE.parent.mkdir(parents=True, exist_ok=True)
    if TOKEN_FILE.exists():
        token = TOKEN_FILE.read_text(encoding="ascii").strip()
        if len(token) >= 16 and token.isalnum():
            return token
    token = secrets.token_hex(12)
    TOKEN_FILE.write_text(token, encoding="ascii")
    return token


def tailscale_info():
    exe = shutil.which("tailscale") or os.path.join(os.environ.get("ProgramFiles", r"C:\Program Files"), "Tailscale", "tailscale.exe")
    flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    try:
        status = json.loads(subprocess.run([exe, "status", "--json"], capture_output=True, text=True, timeout=10, creationflags=flags).stdout)
        addresses = [a for a in status["Self"].get("TailscaleIPs", []) if ":" not in a]
        return (addresses[0] if addresses else None), status["Self"].get("DNSName", "").rstrip(".")
    except (OSError, ValueError, KeyError, subprocess.SubprocessError):
        return None, ""


def resolve(relative):
    """Map a token-relative URL path to an allowed file or listed directory."""
    if "\\" in relative or "\x00" in relative:
        return None, None
    clean = posixpath.normpath(relative).lstrip("/")
    if clean.startswith("..") or "/../" in f"/{clean}/":
        return None, None
    if clean == PAGE:
        return ROOT / clean, "file"
    if clean in LISTED_DIRS:
        return ROOT / clean, "dir"
    parent, name = posixpath.split(clean)
    if parent in LISTED_DIRS and name.lower().endswith(LISTED_DIRS[parent]):
        return ROOT / clean, "file"
    if parent == FONT_DIR and name.lower().endswith(".ttf"):
        return ROOT / clean, "file"
    return None, None


class Handler(BaseHTTPRequestHandler):
    token = ""
    server_version = "ParallaxPerfDashboard"
    sys_version = ""
    seen = set()

    def log_message(self, fmt, *args):
        pass

    def note_client(self, status):
        client = self.client_address[0]
        if client not in Handler.seen or status >= 400:
            Handler.seen.add(client)
            print(f"{self.log_date_time_string()} {client} {self.command} {status} {self.path.split('?')[0][:80]}", flush=True)

    def send_body(self, status, body, content_type, head_only):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.end_headers()
        if not head_only:
            self.wfile.write(body)
        self.note_client(status)

    def not_found(self, head_only):
        self.send_body(HTTPStatus.NOT_FOUND, b"Not found\n", "text/plain; charset=utf-8", head_only)

    def handle_get(self, head_only):
        path = urllib.parse.unquote(urllib.parse.urlsplit(self.path).path)
        loopback = self.client_address[0] in ("127.0.0.1", "::1")
        if path in ("", "/") and loopback:
            self.send_response(HTTPStatus.FOUND)
            self.send_header("Location", f"/{self.token}/{PAGE}")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        prefix = f"/{self.token}/"
        if not path.startswith(prefix):
            return self.not_found(head_only)
        target, kind = resolve(path[len(prefix):])
        if target is None:
            return self.not_found(head_only)
        if kind == "dir":
            if not target.is_dir():
                return self.not_found(head_only)
            rel = target.relative_to(ROOT).as_posix()
            names = sorted(p.name for p in target.iterdir() if p.is_file() and p.name.lower().endswith(LISTED_DIRS[rel]))
            links = "\n".join(f'<a href="{html.escape(urllib.parse.quote(n))}">{html.escape(n)}</a><br>' for n in names)
            body = f"<!doctype html><meta charset=utf-8><title>{html.escape(rel)}</title>\n{links}\n".encode("utf-8")
            return self.send_body(HTTPStatus.OK, body, "text/html; charset=utf-8", head_only)
        if not target.is_file():
            return self.not_found(head_only)
        try:
            body = target.read_bytes()
        except OSError:
            return self.not_found(head_only)
        self.send_body(HTTPStatus.OK, body, TYPES.get(target.suffix.lower(), "application/octet-stream"), head_only)

    def do_GET(self):
        self.handle_get(False)

    def do_HEAD(self):
        self.handle_get(True)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--tailscale", action="store_true", help="also listen on this machine's Tailscale IPv4 address")
    args = parser.parse_args()

    Handler.token = load_token()
    addresses = ["127.0.0.1"]
    dns_name = ""
    if args.tailscale:
        address, dns_name = tailscale_info()
        if address:
            addresses.append(address)
        else:
            print("Tailscale address not found; serving on loopback only.", flush=True)

    servers = []
    for address in addresses:
        try:
            servers.append(ThreadingHTTPServer((address, args.port), Handler))
        except OSError as error:
            print(f"Cannot listen on {address}:{args.port}: {error}", flush=True)
    if not servers:
        sys.exit(1)

    page = f"/{Handler.token}/{PAGE}"
    for server in servers:
        host = server.server_address[0]
        print(f"Serving http://{host}:{args.port}{page}", flush=True)
    if dns_name and len(servers) > 1:
        print(f"Tailnet name: http://{dns_name}:{args.port}{page}", flush=True)

    threads = [threading.Thread(target=s.serve_forever, daemon=True) for s in servers]
    for thread in threads:
        thread.start()
    try:
        for thread in threads:
            thread.join()
    except KeyboardInterrupt:
        pass
    finally:
        for server in servers:
            server.shutdown()


if __name__ == "__main__":
    main()
