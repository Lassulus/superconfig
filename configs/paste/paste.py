"""CGI behind fcgiwrap for p.r/p.krebsco.de (paste, form, imgur) and c.r
(cyberlocker). nginx picks the app with PASTE_APP and the item directory with
PASTE_ITEMS. The on-disk layout is the one of the former htgen-paste,
htgen-imgur and htgen-cyberlocker handlers, so existing items keep working.
"""

import email.utils
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.parse
import uuid

FILE = "@file@"
EXIV2 = "@exiv2@"

ENV = os.environ
ITEMS = ENV["PASTE_ITEMS"]
METHOD = ENV.get("REQUEST_METHOD", "GET")
RAW_PATH, _, QUERY = ENV.get("REQUEST_URI", "/").partition("?")
HOST = ENV.get("HTTP_HOST", "")
STDIN = sys.stdin.buffer
OUT = sys.stdout.buffer


def respond(status, headers=(), body=b""):
    """Send a CGI response; body is bytes or an open file to stream."""
    lines = [f"Status: {status}", *(f"{k}: {v}" for k, v in headers)]
    if isinstance(body, str):
        body = body.encode()
    if isinstance(body, bytes):
        lines.append(f"Content-Length: {len(body)}")
    OUT.write(("\r\n".join(lines) + "\r\n\r\n").encode())
    if isinstance(body, bytes):
        OUT.write(body)
    else:
        shutil.copyfileobj(body, OUT)


def text(status, body):
    respond(status, [("Content-Type", "text/plain; charset=UTF-8")], body)


def send_file(path, content_type):
    with open(path, "rb") as f:
        size = os.fstat(f.fileno()).st_size
        headers = [("Content-Type", content_type), ("Content-Length", size)]
        respond("200 OK", headers, f)


def file_type(path):
    cmd = [FILE, "-ib", path]
    return subprocess.run(cmd, capture_output=True, text=True).stdout.strip()


def body_length():
    return int(ENV.get("CONTENT_LENGTH") or 0)


def read_body(size, head=b""):
    """Yield head and then the next size - len(head) bytes of the body."""
    if head:
        yield head
    left = size - len(head)
    while left > 0:
        chunk = STDIN.read(min(left, 1 << 20))
        if not chunk:
            break
        left -= len(chunk)
        yield chunk


def save(chunks, name=None):
    """Write chunks to ITEMS/name, replacing it, or without a name to the
    nix-base32 sha256 of the content, kept if it exists already.
    Returns (name, path, created)."""
    os.makedirs(ITEMS, exist_ok=True)
    digest = hashlib.sha256()
    tmp = tempfile.NamedTemporaryFile(dir=ITEMS, prefix=".", delete=False)
    try:
        with tmp:
            for chunk in chunks:
                digest.update(chunk)
                tmp.write(chunk)
        replace = name is not None
        name = name or nix32(digest.digest())
        path = os.path.join(ITEMS, name)
        created = not os.path.exists(path)
        if replace or created:
            os.chmod(tmp.name, 0o644)
            os.replace(tmp.name, path)
        return name, path, created
    finally:
        if os.path.exists(tmp.name):
            os.unlink(tmp.name)


NIX32 = "0123456789abcdfghijklmnpqrsvwxyz"


def nix32(digest):
    """Nix's base32 (nix-hash --to-base32)."""
    out = ""
    for n in reversed(range((len(digest) * 8 - 1) // 5 + 1)):
        byte, bit = divmod(n * 5, 8)
        c = digest[byte] >> bit
        if byte + 1 < len(digest):
            c |= digest[byte + 1] << (8 - bit)
        out += NIX32[c & 0x1F]
    return out


def find(ident):
    """The item whose name starts with ident (7+ chars), if exactly one."""
    if len(ident) < 7 or not re.fullmatch("[0-9a-z]+", ident):
        return None
    try:
        names = os.listdir(ITEMS)
    except FileNotFoundError:
        return None
    hits = [n for n in names if n.startswith(ident) and n.isalnum()]
    return os.path.join(ITEMS, hits[0]) if len(hits) == 1 else None


def short(name):
    return name[:7] if find(name[:7]) else None


def paste():
    if METHOD == "POST" and RAW_PATH == "/":
        name, path, _ = save(read_body(body_length()))
        override = ENV.get("HTTP_CONTENT_TYPE_OVERRIDE")
        if override:
            with open(path + ".content_type", "w") as f:
                f.write(override)
        refs = [f"http://{HOST}/{n}" for n in (name, short(name)) if n]
        return text("200 OK", "".join(ref + "\n" for ref in refs))
    item = find(RAW_PATH[1:])
    if item and METHOD == "GET":
        try:
            with open(item + ".content_type") as f:
                content_type = f.read()
        except FileNotFoundError:
            content_type = file_type(item)
        return send_file(item, content_type)
    if item and METHOD == "DELETE":
        os.unlink(item)
        return respond("200 OK")
    respond("404 Not Found")


def form():
    """multipart/form-data upload from the p.krebsco.de page: the file is the
    first part, after its headers and before "\r\n--boundary--\r\n"."""
    if METHOD != "POST":
        return respond("404 Not Found")
    boundary = ENV.get("CONTENT_TYPE", "").partition("boundary=")[2]
    boundary = boundary.partition(";")[0].strip('"')
    length = body_length()
    head = STDIN.read(min(length, 1 << 16))
    start = head.find(b"\r\n\r\n") + 4
    size = length - start - (len(boundary) + 8)
    if not boundary or start < 4 or size < 0:
        return text("400 Bad Request", "bad multipart upload\n")
    name, _, _ = save(read_body(size, head[start:start + size]))
    text("200 OK", f"https://{HOST}/{short(name) or name}\n")


def imgur_response(status, data=None):
    """https://api.imgur.com/models/basic"""
    code = int(status.split()[0])
    body = {"data": data, "status": code, "success": 200 <= code <= 299}
    body = json.dumps(body, separators=(",", ":")) + "\n"
    respond(status, [("Content-Type", "application/json; charset=UTF-8")],
            body)


def image_info(path):
    cmd = [EXIV2, "print", path]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    info = {}
    for line in out.splitlines():
        key, sep, value = line.partition(":")
        if sep:
            info[key.strip()] = value.strip()
    size = re.fullmatch(r"([0-9]+)\s*x\s*([0-9]+)", info.get("Image size", ""))
    if "MIME type" not in info or not size:
        return None
    return info["MIME type"], int(size[1]), int(size[2])


def imgur():
    query = urllib.parse.parse_qs(QUERY)
    ident = RAW_PATH.rpartition("/")[2]
    if METHOD == "POST" and RAW_PATH == "/image":
        name, path, created = save(read_body(body_length()))
        info = image_info(path)
        if not info:
            if created:
                os.unlink(path)
            return imgur_response("400 Bad Request")
        content_type, width, height = info
        scheme = ENV.get("REQUEST_SCHEME", "http")
        deletehash = uuid.uuid4().hex
        data = {
            "id": name,
            "title": query.get("title", [None])[0],
            "description": query.get("description", [None])[0],
            "datetime": time.time(),
            "type": content_type,
            "animated": False,
            "width": width,
            "height": height,
            "size": os.path.getsize(path),
            "views": 0,
            "bandwidth": 0,
            "vote": None,
            "favorite": False,
            "nsfw": None,
            "section": None,
            "account_url": None,
            "acount_id": 0,
            "is_ad": False,
            "is_most_viral": False,
            "tags": [],
            "ad_type": 0,
            "ad_url": "",
            "in_gallery": False,
            "deletehash": urllib.parse.quote(
                f"{name}?deletehash={deletehash}", safe=""
            ),
            "name": "",
            "link": f"{scheme}://{HOST}/image/{short(name) or name}",
        }
        os.setxattr(path, "user.deletehash", deletehash.encode())
        os.setxattr(path, "user.data", json.dumps(data).encode())
        return imgur_response("200 OK", data)
    item = find(ident)
    if item and METHOD == "GET" and RAW_PATH.startswith("/image/"):
        try:
            content_type = json.loads(os.getxattr(item, "user.data"))["type"]
        except (OSError, ValueError, KeyError):
            content_type = "application/octet-stream"
        return send_file(item, content_type)
    if (
        item
        and METHOD == "DELETE"
        and RAW_PATH.startswith("/image/delete/")
    ):
        given = query.get("deletehash", [""])[0]
        if given.encode() != os.getxattr(item, "user.deletehash"):
            return imgur_response("401 Unauthorized")
        os.unlink(item)
        return imgur_response("200 OK")
    respond("404 Not Found")


def cyberlocker():
    """Files by path; the raw request path, with repeated slashes collapsed,
    percent-encoded into one file name."""
    name = urllib.parse.quote(re.sub("/+", "/", RAW_PATH), safe="")
    path = os.path.join(ITEMS, name)
    if METHOD in ("POST", "PUT"):
        save(read_body(body_length()), name)
        return respond("204 No Content")
    if not os.path.exists(path):
        return respond("404 Not Found")
    if METHOD == "GET":
        since = ENV.get("HTTP_IF_MODIFIED_SINCE")
        try:
            since = since and email.utils.parsedate_to_datetime(since)
        except (TypeError, ValueError):
            since = None
        if since and os.path.getmtime(path) < since.timestamp():
            return respond("304 Not Modified")
        return send_file(path, file_type(path))
    if METHOD == "DELETE":
        os.unlink(path)
        return respond("204 No Content")
    respond("404 Not Found")


{"paste": paste, "form": form, "imgur": imgur, "cyberlocker": cyberlocker}[
    ENV["PASTE_APP"]
]()
