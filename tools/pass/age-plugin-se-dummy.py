#!/usr/bin/env python3
"""
Dummy age-plugin-se for Linux.

This plugin allows encrypting secrets to Secure Enclave recipients (age1se... addresses)
from Linux machines. The encrypted files can then be decrypted on macOS using the real
age-plugin-se with hardware Secure Enclave support.

The crypto is identical to the real plugin - only the key storage differs:
- Real plugin: Private keys stored in Apple Secure Enclave hardware
- This plugin: Only supports encryption (no private key storage)
"""

import sys
import io
import base64
import hashlib
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305


def bech32_decode(s):
    """Simple bech32 decode for age1se addresses."""
    charset = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
    hrp_end = s.rfind('1')
    if hrp_end < 1:
        return None
    data = s[hrp_end + 1:]
    decoded = []
    for c in data:
        if c not in charset:
            return None
        decoded.append(charset.index(c))
    # Convert from 5-bit to 8-bit groups
    bits = 0
    value = 0
    result = []
    for d in decoded[:-6]:  # Skip checksum
        value = (value << 5) | d
        bits += 5
        if bits >= 8:
            bits -= 8
            result.append((value >> bits) & 0xff)
            value &= (1 << bits) - 1
    return bytes(result)


def write_stdout(s):
    """Write to stdout with explicit flush (unbuffered)."""
    stdout_raw.write(s.encode('utf-8'))
    stdout_raw.flush()


def handle_recipient_v1():
    """Handle the age plugin recipient-v1 protocol."""
    file_keys = []
    recipients = []
    got_done = False

    # Read commands until -> done
    while True:
        line = sys.stdin.readline()
        if not line:  # EOF
            break
        line = line.strip()

        if line.startswith("-> add-recipient "):
            recipients.append(line[17:])
        elif line == "-> wrap-file-key":
            # Read body lines until empty line OR next command
            body_parts = []
            while True:
                body_line = sys.stdin.readline()
                if not body_line:
                    break
                body_line_stripped = body_line.strip()
                if body_line_stripped == "":
                    break  # Empty line terminates body
                if body_line_stripped.startswith("->"):
                    # Next command encountered
                    if body_line_stripped == "-> done":
                        got_done = True
                    break
                body_parts.append(body_line_stripped)
            file_keys.append("".join(body_parts))
            if got_done:
                break
        elif line == "-> done":
            got_done = True
            break
        # Ignore other lines (grease commands, extension-labels, etc.)

    if not got_done:
        sys.exit(1)

    # Process each file key for each recipient
    for file_idx, file_key_b64 in enumerate(file_keys):
        for recipient in recipients:
            try:
                # Decode recipient public key (compressed P-256, 33 bytes)
                pubkey_bytes = bech32_decode(recipient)
                if not pubkey_bytes:
                    raise ValueError("Failed to decode recipient")

                # Generate tag from public key hash (first 4 bytes of SHA256)
                tag = base64.b64encode(
                    hashlib.sha256(pubkey_bytes).digest()[:4]
                ).decode().rstrip('=')

                # Decode file key (add padding for base64)
                padding = (4 - len(file_key_b64) % 4) % 4
                file_key = base64.b64decode(file_key_b64 + '=' * padding)

                # Load P-256 public key
                recipient_pubkey = ec.EllipticCurvePublicKey.from_encoded_point(
                    ec.SECP256R1(), pubkey_bytes
                )

                # Generate ephemeral key pair
                ephemeral_private = ec.generate_private_key(ec.SECP256R1())
                ephemeral_public = ephemeral_private.public_key()
                ephemeral_bytes = ephemeral_public.public_bytes(
                    serialization.Encoding.X962,
                    serialization.PublicFormat.CompressedPoint
                )

                # ECDH shared secret
                shared = ephemeral_private.exchange(ec.ECDH(), recipient_pubkey)

                # HKDF to derive wrapping key (matches age-plugin-se format)
                # salt = ephemeral || recipient_pubkey, info = "piv-p256"
                hkdf_salt = ephemeral_bytes + pubkey_bytes
                wrapping_key = HKDF(
                    algorithm=hashes.SHA256(),
                    length=32,
                    salt=hkdf_salt,
                    info=b"piv-p256",
                ).derive(shared)

                # Encrypt with ChaCha20-Poly1305 (zero nonce, no AAD)
                cipher = ChaCha20Poly1305(wrapping_key)
                encrypted = cipher.encrypt(b'\x00' * 12, file_key, None)

                # Format output (base64 without padding)
                ephemeral_b64 = base64.b64encode(ephemeral_bytes).decode().rstrip('=')
                encrypted_b64 = base64.b64encode(encrypted).decode().rstrip('=')

                # Output stanza (header + body)
                header = f"-> recipient-stanza {file_idx} piv-p256 {tag} {ephemeral_b64}"
                write_stdout(header + '\n')
                write_stdout(encrypted_b64 + '\n')

            except Exception:
                pass  # Silently skip failed recipients

    # Signal completion with empty line after done (required by plugin protocol)
    write_stdout("-> done\n\n")
    sys.exit(0)


if __name__ == "__main__":
    # Use unbuffered stdout for reliable plugin communication
    stdout_raw = io.FileIO(sys.stdout.fileno(), mode='w', closefd=False)

    if len(sys.argv) > 1 and sys.argv[1] == '--age-plugin=recipient-v1':
        handle_recipient_v1()
    else:
        # Unknown mode
        sys.exit(1)
