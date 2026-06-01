"""HTTP upload endpoint that writes files under /var/lib/ipfs/download and pins them.

Supports resumable uploads via `Content-Range: bytes <start>-<end>/<total>`.
The staging file is `<STAGING_DIR>/<sha256(rel)>.upload` so the staging path
is deterministic from the destination path; clients resume by re-POSTing
the same URL.

Protocol:
  POST /<path>  body=N bytes, no Content-Range
        One-shot upload: equivalent to a single chunk covering the whole file.

  POST /<path>  body=N bytes, Content-Range: bytes <start>-<end>/<total>
        Chunked upload. `start` must equal the current staging size, or 0
        to truncate and start fresh. When the staging size reaches `total`,
        the staging file is moved to /var/lib/ipfs/download/<path> and
        `ipfs add --nocopy --pin` is run. Returns 200 with the CID on
        completion, 308 with `Upload-Offset: <size>` while incomplete.

  POST /<path>  body=0, no Content-Range
        Status check. Returns 200 with `Upload-Offset: <size>` if a
        staging file exists, 404 otherwise.

URL path segments are restricted to [A-Za-z0-9._-]. Re-uploading the same
path overwrites the file; the previous CID is left in IPFS but unreferenced
by this service.
"""

from __future__ import annotations

import hashlib
import http.server
import os
import re
import socketserver
import subprocess
import sys
import threading

DOWNLOAD_ROOT = os.environ.get("DOWNLOAD_ROOT", "/var/lib/ipfs/download")
STAGING_DIR = os.environ.get("STAGING_DIR", "/var/lib/ipfs/download/incoming/uploader")
IPFS_BIN = os.environ.get("IPFS_BIN", "ipfs")
CHUNK = 1 << 20  # 1 MiB
_CONTENT_RANGE = re.compile(r"^bytes (\d+)-(\d+)/(\d+)$")

_SAFE_SEGMENT = re.compile(r"^[A-Za-z0-9._\-]+$")


def safe_relpath(url_path: str) -> str | None:
    raw = url_path.split("?", 1)[0].strip("/")
    if not raw:
        return None
    segments = raw.split("/")
    for seg in segments:
        if seg in {"", ".", ".."} or not _SAFE_SEGMENT.match(seg):
            return None
    return "/".join(segments)


def staging_path(rel: str) -> str:
    sid = hashlib.sha256(rel.encode("utf-8")).hexdigest()
    return os.path.join(STAGING_DIR, f"{sid}.upload")


_locks_mu = threading.Lock()
_locks: dict[str, threading.Lock] = {}


def lock_for(rel: str) -> threading.Lock:
    # Serializes concurrent POSTs targeting the same staging file. Without
    # this, two threads handling the same chunk (e.g. a client retry after a
    # lost response) can both pass the start==current_size check and both
    # open("ab"), duplicating bytes and shifting the resume offset.
    with _locks_mu:
        lock = _locks.get(rel)
        if lock is None:
            lock = threading.Lock()
            _locks[rel] = lock
        return lock


class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "ipfs-upload/1"

    def do_POST(self) -> None:  # noqa: N802 - stdlib interface
        rel = safe_relpath(self.path)
        if rel is None:
            self.send_error(400, "invalid path")
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self.send_error(400, "bad Content-Length")
            return
        if length < 0:
            self.send_error(400, "bad Content-Length")
            return

        cr_header = self.headers.get("Content-Range")
        staging = staging_path(rel)

        with lock_for(rel):
            self._handle_locked(rel, length, cr_header, staging)

    def _handle_locked(
        self, rel: str, length: int, cr_header: str | None, staging: str
    ) -> None:
        # Status check: empty body + no Content-Range.
        if length == 0 and not cr_header:
            try:
                size = os.path.getsize(staging)
            except OSError:
                self.send_error(404, "no upload in progress")
                return
            body = (str(size) + "\n").encode("ascii")
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Upload-Offset", str(size))
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        # Parse Content-Range or derive a single-chunk request.
        if cr_header:
            m = _CONTENT_RANGE.match(cr_header)
            if not m:
                self.send_error(400, "bad Content-Range")
                return
            start, end, total = int(m.group(1)), int(m.group(2)), int(m.group(3))
            if start < 0 or end < start or end >= total:
                self.send_error(400, "bad Content-Range")
                return
            chunk_len = end - start + 1
            if length != chunk_len:
                self.send_error(400, "Content-Length doesn't match Content-Range")
                return
        else:
            if length == 0:
                self.send_error(411, "Content-Length required")
                return
            start, total, chunk_len = 0, length, length

        # Current staging size and offset enforcement.
        try:
            current_size = os.path.getsize(staging)
        except OSError:
            current_size = 0

        if start == 0:
            mode = "wb"  # truncate / fresh start
        elif start == current_size:
            mode = "ab"
        else:
            self.send_error(
                409, f"offset mismatch: expected {current_size}, got {start}"
            )
            return

        try:
            with open(staging, mode) as f:
                remaining = chunk_len
                while remaining > 0:
                    data = self.rfile.read(min(CHUNK, remaining))
                    if not data:
                        break
                    f.write(data)
                    remaining -= len(data)
                if remaining != 0:
                    raise OSError(f"short read: {remaining} bytes missing")
        except OSError as e:
            # Roll the staging file back to the chunk's start so the client
            # can retry this chunk from a consistent offset.
            try:
                with open(staging, "r+b") as fix:
                    fix.truncate(start)
            except OSError:
                pass
            self.send_error(500, f"write failed: {e}")
            return

        try:
            new_size = os.path.getsize(staging)
        except OSError as e:
            self.send_error(500, f"stat failed: {e}")
            return

        if new_size < total:
            self.send_response(308)
            self.send_header("Upload-Offset", str(new_size))
            self.send_header("Range", f"bytes=0-{new_size - 1}")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        if new_size > total:
            # Client over-sent (shouldn't happen given our checks, but guard).
            try:
                with open(staging, "r+b") as fix:
                    fix.truncate(total)
            except OSError as e:
                self.send_error(500, f"truncate failed: {e}")
                return

        # Complete: move staging → dst and pin.
        dst = os.path.join(DOWNLOAD_ROOT, rel)
        dst_dir = os.path.dirname(dst) or DOWNLOAD_ROOT
        try:
            os.makedirs(dst_dir, exist_ok=True)
            os.replace(staging, dst)
        except OSError as e:
            self.send_error(500, f"finalize failed: {e}")
            return

        try:
            result = subprocess.run(
                [IPFS_BIN, "add", "--nocopy", "--pin", "--quieter", dst],
                check=True,
                capture_output=True,
                text=True,
            )
        except subprocess.CalledProcessError as e:
            msg = (e.stderr or e.stdout or "").strip() or "unknown error"
            self.send_error(500, f"ipfs add failed: {msg}")
            return

        cid = result.stdout.strip()
        body = (cid + "\n").encode("ascii")
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt: str, *args: object) -> None:
        sys.stderr.write(f"{self.address_string()} {fmt % args}\n")


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main() -> None:
    os.makedirs(STAGING_DIR, exist_ok=True)
    bind = os.environ.get("BIND", "127.0.0.1")
    port = int(os.environ.get("PORT", "8090"))
    with Server((bind, port), Handler) as s:
        s.serve_forever()


if __name__ == "__main__":
    main()
