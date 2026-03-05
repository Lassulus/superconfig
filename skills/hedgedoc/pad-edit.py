#!/usr/bin/env python3
"""Edit a HedgeDoc pad in-place via websocket (socket.io protocol)."""
import sys
import json
import http.cookiejar
import urllib.request
import ssl

try:
    import websocket
except ImportError:
    import subprocess
    import os

    # Bootstrap: re-exec under nix shell with websocket-client
    os.execvp(
        "nix",
        [
            "nix",
            "shell",
            "nixpkgs#python3Packages.websocket-client",
            "-c",
            "python3",
            __file__,
        ]
        + sys.argv[1:],
    )

HEDGEDOC_URL = "https://pad.lassul.us"


def js_length(s):
    """Return JavaScript string length (UTF-16 code units, not Unicode codepoints)."""
    return len(s.encode("utf-16-le")) // 2


def main():
    if len(sys.argv) < 2:
        print("Usage: pad-edit.py <pad-id> [file]", file=sys.stderr)
        print("       echo 'content' | pad-edit.py <pad-id>", file=sys.stderr)
        sys.exit(1)

    pad_id = sys.argv[1]

    # Read new content
    if len(sys.argv) >= 3 and sys.argv[2] != "-":
        with open(sys.argv[2]) as f:
            new_content = f.read()
    else:
        new_content = sys.stdin.read()

    # Strip single trailing newline (added by shell heredoc/echo)
    if new_content.endswith("\n"):
        new_content = new_content[:-1]

    # Step 1: Get session cookie
    ctx = ssl.create_default_context()
    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(
        urllib.request.HTTPCookieProcessor(cj),
        urllib.request.HTTPSHandler(context=ctx),
    )
    opener.open(f"{HEDGEDOC_URL}/{pad_id}")
    cookie_str = "; ".join(f"{c.name}={c.value}" for c in cj)
    if not cookie_str:
        print("ERROR: Failed to get session cookie", file=sys.stderr)
        sys.exit(1)

    # Step 2: Connect websocket
    ws_url = f"wss://pad.lassul.us/socket.io/?noteId={pad_id}&EIO=4&transport=websocket"
    ws = websocket.create_connection(
        ws_url,
        header=[f"Cookie: {cookie_str}", f"Origin: {HEDGEDOC_URL}"],
        sslopt={"cert_reqs": ssl.CERT_REQUIRED},
    )

    ws.recv()  # handshake: 0{"sid":...}
    ws.send("40")  # namespace connect

    # Read until doc event, handle pings
    revision = None
    old_js_len = None
    for _ in range(20):
        ws.settimeout(5)
        msg = ws.recv()
        if msg == "2":
            ws.send("3")
            continue
        if '"doc"' in msg:
            payload = json.loads(msg[2:])
            doc_data = payload[1]
            revision = doc_data["revision"]
            old_js_len = js_length(doc_data["str"])
            break

    if revision is None:
        print("ERROR: Did not receive document state", file=sys.stderr)
        ws.close()
        sys.exit(1)

    # Step 3: Build and send OT operation
    escaped_new = json.dumps(new_content, ensure_ascii=False)

    if old_js_len == 0:
        op = f"[{escaped_new}]"
    else:
        op = f"[-{old_js_len},{escaped_new}]"

    ws.send(f'42["operation",{revision},{op}]')

    # Step 4: Wait for ack
    ack_received = False
    for _ in range(20):
        try:
            ws.settimeout(5)
            msg = ws.recv()
            if msg == "2":
                ws.send("3")
                continue
            if '"ack"' in msg:
                ack_received = True
                break
        except websocket.WebSocketTimeoutException:
            break

    ws.close()

    if ack_received:
        print(f"✅ Updated {HEDGEDOC_URL}/{pad_id}")
    else:
        print(
            f"⚠️  No ack received. Check {HEDGEDOC_URL}/{pad_id}", file=sys.stderr
        )
        sys.exit(1)


if __name__ == "__main__":
    main()
