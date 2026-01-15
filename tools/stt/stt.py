#!/usr/bin/env python3
"""
Real-time streaming speech-to-text using Vosk.
Reads audio from stdin and outputs words as they're recognized.
"""

import argparse
import json
import os
import struct
import sys
import zipfile
from pathlib import Path
from urllib.request import urlretrieve

from vosk import KaldiRecognizer, Model, SetLogLevel

MODEL_DIR = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "vosk"

# Models organized by size: small (~40MB), medium (~128MB), large (~1-2GB)
MODELS = {
    "en": {
        "small": "vosk-model-small-en-us-0.15",
        "medium": "vosk-model-en-us-0.22-lgraph",
        "large": "vosk-model-en-us-0.22",
    },
    "de": {
        "small": "vosk-model-small-de-0.15",
        "medium": "vosk-model-de-0.21",
        "large": "vosk-model-de-0.21",
    },
    "fr": {
        "small": "vosk-model-small-fr-0.22",
        "medium": "vosk-model-fr-0.22",
        "large": "vosk-model-fr-0.22",
    },
    "es": {
        "small": "vosk-model-small-es-0.42",
        "medium": "vosk-model-es-0.42",
        "large": "vosk-model-es-0.42",
    },
    "ru": {
        "small": "vosk-model-small-ru-0.22",
        "medium": "vosk-model-ru-0.42",
        "large": "vosk-model-ru-0.42",
    },
    "cn": {
        "small": "vosk-model-small-cn-0.22",
        "medium": "vosk-model-cn-0.22",
        "large": "vosk-model-cn-0.22",
    },
    "ja": {
        "small": "vosk-model-small-ja-0.22",
        "medium": "vosk-model-ja-0.22",
        "large": "vosk-model-ja-0.22",
    },
}


def download_model(lang: str, size: str = "small") -> Path:
    """Download vosk model if not present."""
    lang_models = MODELS.get(lang)
    if not lang_models:
        # Fall back to English if language not available
        print(f"No model for '{lang}', using English", file=sys.stderr)
        lang_models = MODELS["en"]
        lang = "en"

    model_name = lang_models.get(size, lang_models["small"])

    model_path = MODEL_DIR / model_name
    if model_path.exists():
        return model_path

    print(f"Downloading model {model_name}...", file=sys.stderr)
    MODEL_DIR.mkdir(parents=True, exist_ok=True)

    url = f"https://alphacephei.com/vosk/models/{model_name}.zip"
    zip_path = MODEL_DIR / f"{model_name}.zip"

    urlretrieve(url, zip_path)

    print("Extracting...", file=sys.stderr)
    with zipfile.ZipFile(zip_path, "r") as z:
        z.extractall(MODEL_DIR)
    zip_path.unlink()

    print("Model ready", file=sys.stderr)
    return model_path


def parse_wav_header(data: bytes) -> tuple[int, int, int, int]:
    """Parse WAV header, return (sample_rate, channels, bits_per_sample, data_offset)."""
    if len(data) < 44 or data[:4] != b"RIFF" or data[8:12] != b"WAVE":
        raise ValueError("Invalid WAV header")

    pos = 12
    sample_rate = channels = bits_per_sample = 0
    while pos < len(data) - 8:
        chunk_id = data[pos : pos + 4]
        chunk_size = struct.unpack("<I", data[pos + 4 : pos + 8])[0]
        if chunk_id == b"fmt ":
            channels = struct.unpack("<H", data[pos + 10 : pos + 12])[0]
            sample_rate = struct.unpack("<I", data[pos + 12 : pos + 16])[0]
            bits_per_sample = struct.unpack("<H", data[pos + 22 : pos + 24])[0]
        elif chunk_id == b"data":
            return sample_rate, channels, bits_per_sample, pos + 8
        pos += 8 + chunk_size

    raise ValueError("No data chunk found")


def convert_audio(data: bytes, in_rate: int, in_channels: int, in_bits: int) -> bytes:
    """Convert audio to 16kHz mono 16-bit for Vosk."""
    import array

    # Align data to sample boundary
    bytes_per_sample = in_bits // 8
    frame_size = in_channels * bytes_per_sample
    aligned_len = (len(data) // frame_size) * frame_size
    if aligned_len == 0:
        return b""
    data = data[:aligned_len]

    # Convert to samples
    if in_bits == 16:
        samples = array.array("h", data)
    elif in_bits == 8:
        samples = array.array("h", [(s - 128) * 256 for s in data])
    else:
        raise ValueError(f"Unsupported bit depth: {in_bits}")

    # Convert to mono
    if in_channels == 2:
        mono = array.array("h")
        for i in range(0, len(samples) - 1, 2):
            mono.append((samples[i] + samples[i + 1]) // 2)
        samples = mono

    # Resample to 16kHz if needed
    if in_rate != 16000:
        ratio = 16000 / in_rate
        new_len = int(len(samples) * ratio)
        resampled = array.array("h")
        for i in range(new_len):
            src_idx = min(int(i / ratio), len(samples) - 1)
            resampled.append(samples[src_idx])
        samples = resampled

    return samples.tobytes()


def main():
    parser = argparse.ArgumentParser(description="Real-time STT using Vosk")
    parser.add_argument(
        "-l",
        "--language",
        default=os.environ.get("VOSK_LANG", "en"),
        help="Language: en, de, fr, es, ru, cn, ja (default: en)",
    )
    parser.add_argument(
        "-s",
        "--size",
        default=os.environ.get("VOSK_SIZE", "small"),
        choices=["small", "medium", "large"],
        help="Model size: small (~40MB), medium (~128MB), large (~1-2GB) (default: small)",
    )
    parser.add_argument(
        "-w",
        "--words",
        action="store_true",
        help="Output individual words as they're recognized",
    )
    args = parser.parse_args()

    # Suppress Vosk logging
    SetLogLevel(-1)

    model_path = download_model(args.language, args.size)
    model = Model(str(model_path))

    # Read WAV header
    stdin = sys.stdin.buffer
    header_buf = stdin.read(4096)
    sample_rate, channels, bits, data_offset = parse_wav_header(header_buf)

    print(f"Audio: {sample_rate}Hz, {channels}ch, {bits}bit", file=sys.stderr)
    print("Listening...", file=sys.stderr)

    # Create recognizer for 16kHz audio
    rec = KaldiRecognizer(model, 16000)
    rec.SetWords(True)

    # Process initial audio from header buffer
    initial_audio = header_buf[data_offset:]
    if initial_audio:
        converted = convert_audio(initial_audio, sample_rate, channels, bits)
        rec.AcceptWaveform(converted)

    # Process audio stream
    chunk_size = int(sample_rate * channels * (bits // 8) * 0.1)  # 100ms chunks

    while True:
        data = stdin.read(chunk_size)
        if not data:
            break

        converted = convert_audio(data, sample_rate, channels, bits)

        if rec.AcceptWaveform(converted):
            result = json.loads(rec.Result())
            text = result.get("text", "")
            if text:
                if args.words:
                    # Show final sentence on stderr with period and newline
                    print(f"\r\033[K{text}.", file=sys.stderr, flush=True)
                print(text, flush=True)
        elif args.words:
            partial = json.loads(rec.PartialResult())
            text = partial.get("partial", "")
            if text:
                # Show partial with corrections on stderr
                print(f"\r\033[K{text}", end="", file=sys.stderr, flush=True)

    # Final result
    result = json.loads(rec.FinalResult())
    text = result.get("text", "")
    if text:
        if args.words:
            print(f"\r\033[K{text}.", file=sys.stderr, flush=True)
        print(text, flush=True)

    print("Stream ended", file=sys.stderr)


if __name__ == "__main__":
    main()
