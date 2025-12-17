#!/usr/bin/env python3
"""
TUI Stream Client - Audio conference client with TUI

Connects to a TUI Stream server, streams microphone audio,
receives audio from other participants, and provides a TUI
for volume control and muting.
"""

import argparse
import asyncio
import curses
import json
import os
import struct
import subprocess
import sys
import threading
from dataclasses import dataclass, field
from typing import Dict, Optional

# Protocol constants
MSG_TYPE_AUDIO = 1
MSG_TYPE_CONTROL = 2

# Audio settings
SAMPLE_RATE = 48000
CHANNELS = 1
AUDIO_FORMAT = "s16le"  # signed 16-bit little-endian
FRAME_SIZE = 960  # 20ms at 48kHz
BYTES_PER_FRAME = FRAME_SIZE * 2 * CHANNELS  # 16-bit = 2 bytes


@dataclass
class Participant:
    client_id: int
    name: str
    volume: float = 1.0  # 0.0 to 2.0
    muted: bool = False
    ffplay_proc: Optional[subprocess.Popen] = None
    audio_pipe: Optional[int] = None


@dataclass
class ClientState:
    my_id: int = 0
    my_name: str = ""
    participants: Dict[int, Participant] = field(default_factory=dict)
    selected_idx: int = 0
    connected: bool = False
    self_muted: bool = False
    lock: threading.Lock = field(default_factory=threading.Lock)
    status_message: str = "Connecting..."


class TUIClient:
    def __init__(self, server_host: str, server_port: int, name: str):
        self.server_host = server_host
        self.server_port = server_port
        self.name = name
        self.state = ClientState(my_name=name)
        self.reader: Optional[asyncio.StreamReader] = None
        self.writer: Optional[asyncio.StreamWriter] = None
        self.running = True
        self.stdscr = None
        self.mic_proc: Optional[subprocess.Popen] = None

    def start_participant_playback(self, participant: Participant):
        """Start ffplay process for a participant's audio."""
        if participant.ffplay_proc is not None:
            return

        # Create a pipe for audio data
        read_fd, write_fd = os.pipe()
        participant.audio_pipe = write_fd

        # Start ffplay reading from the pipe
        participant.ffplay_proc = subprocess.Popen(
            [
                "ffplay",
                "-nodisp",
                "-autoexit",
                "-f", AUDIO_FORMAT,
                "-ar", str(SAMPLE_RATE),
                "-ac", str(CHANNELS),
                "-i", "pipe:0",
                "-loglevel", "quiet",
            ],
            stdin=read_fd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        os.close(read_fd)

    def stop_participant_playback(self, participant: Participant):
        """Stop ffplay process for a participant."""
        if participant.ffplay_proc:
            participant.ffplay_proc.terminate()
            participant.ffplay_proc = None
        if participant.audio_pipe:
            try:
                os.close(participant.audio_pipe)
            except OSError:
                pass
            participant.audio_pipe = None

    def apply_volume(self, audio_data: bytes, volume: float) -> bytes:
        """Apply volume adjustment to audio data."""
        if volume == 1.0:
            return audio_data

        # Convert bytes to samples, apply volume, convert back
        import array
        samples = array.array('h')
        samples.frombytes(audio_data)

        for i in range(len(samples)):
            sample = int(samples[i] * volume)
            # Clamp to 16-bit range
            samples[i] = max(-32768, min(32767, sample))

        return samples.tobytes()

    async def handle_audio(self, sender_id: int, audio_data: bytes):
        """Handle incoming audio from a participant."""
        with self.state.lock:
            if sender_id not in self.state.participants:
                return

            participant = self.state.participants[sender_id]

            if participant.muted:
                return

            # Start playback if not started
            if participant.ffplay_proc is None:
                self.start_participant_playback(participant)

            # Apply volume and write to pipe
            if participant.audio_pipe:
                try:
                    adjusted = self.apply_volume(audio_data, participant.volume)
                    os.write(participant.audio_pipe, adjusted)
                except OSError:
                    # Pipe broken, restart playback
                    self.stop_participant_playback(participant)

    async def handle_control(self, data: bytes):
        """Handle control messages from server."""
        try:
            msg = json.loads(data.decode('utf-8'))
        except json.JSONDecodeError:
            return

        msg_type = msg.get("type")

        if msg_type == "welcome":
            self.state.my_id = msg["your_id"]
            self.state.connected = True
            self.state.status_message = f"Connected as '{self.name}' (id={self.state.my_id})"

        elif msg_type == "client_list":
            with self.state.lock:
                current_ids = set(self.state.participants.keys())
                new_ids = set()

                for client in msg["clients"]:
                    cid = client["id"]
                    if cid == self.state.my_id:
                        continue  # Skip self
                    new_ids.add(cid)

                    if cid not in self.state.participants:
                        self.state.participants[cid] = Participant(
                            client_id=cid,
                            name=client["name"]
                        )
                    else:
                        self.state.participants[cid].name = client["name"]

                # Remove disconnected participants
                for cid in current_ids - new_ids:
                    p = self.state.participants.pop(cid, None)
                    if p:
                        self.stop_participant_playback(p)

        elif msg_type == "client_left":
            cid = msg["id"]
            with self.state.lock:
                p = self.state.participants.pop(cid, None)
                if p:
                    self.stop_participant_playback(p)

    async def receive_loop(self):
        """Receive and process messages from server."""
        try:
            while self.running:
                # Read header: 1 byte type + 2 bytes sender_id + 4 bytes size
                header = await self.reader.readexactly(7)
                msg_type, sender_id, size = struct.unpack(">BHI", header)

                data = await self.reader.readexactly(size)

                if msg_type == MSG_TYPE_AUDIO:
                    await self.handle_audio(sender_id, data)
                elif msg_type == MSG_TYPE_CONTROL:
                    await self.handle_control(data)

        except asyncio.IncompleteReadError:
            self.state.status_message = "Disconnected from server"
            self.state.connected = False
        except Exception as e:
            self.state.status_message = f"Error: {e}"
            self.state.connected = False

    async def send_audio(self, data: bytes):
        """Send audio data to server."""
        if not self.writer or not self.state.connected:
            return
        if self.state.self_muted:
            return

        header = struct.pack(">BI", MSG_TYPE_AUDIO, len(data))
        try:
            self.writer.write(header + data)
            await self.writer.drain()
        except Exception:
            pass

    def mic_capture_thread(self, loop: asyncio.AbstractEventLoop):
        """Thread to capture microphone audio."""
        self.mic_proc = subprocess.Popen(
            [
                "ffmpeg",
                "-f", "pulse",
                "-i", "default",
                "-ar", str(SAMPLE_RATE),
                "-ac", str(CHANNELS),
                "-f", AUDIO_FORMAT,
                "-",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )

        while self.running and self.mic_proc.poll() is None:
            try:
                data = self.mic_proc.stdout.read(BYTES_PER_FRAME)
                if data and self.state.connected:
                    asyncio.run_coroutine_threadsafe(self.send_audio(data), loop)
            except Exception:
                break

        if self.mic_proc:
            self.mic_proc.terminate()

    async def connect(self):
        """Connect to the server."""
        try:
            self.reader, self.writer = await asyncio.open_connection(
                self.server_host, self.server_port
            )

            # Send name
            name_bytes = self.name.encode('utf-8')
            self.writer.write(struct.pack(">I", len(name_bytes)) + name_bytes)
            await self.writer.drain()

            self.state.status_message = "Connected, waiting for welcome..."
            return True
        except Exception as e:
            self.state.status_message = f"Connection failed: {e}"
            return False

    def draw_tui(self):
        """Draw the TUI interface."""
        if not self.stdscr:
            return

        try:
            self.stdscr.clear()
            h, w = self.stdscr.getmaxyx()

            # Header
            header = f" TUI Stream - {self.name} "
            if self.state.self_muted:
                header += "[MUTED] "
            self.stdscr.addstr(0, 0, "=" * w)
            self.stdscr.addstr(0, (w - len(header)) // 2, header, curses.A_BOLD)

            # Status
            status = self.state.status_message[:w-1]
            self.stdscr.addstr(1, 0, status)

            # Participants header
            self.stdscr.addstr(3, 0, "Participants:", curses.A_UNDERLINE)
            self.stdscr.addstr(3, 20, "Volume", curses.A_UNDERLINE)
            self.stdscr.addstr(3, 35, "Status", curses.A_UNDERLINE)

            # Participant list
            with self.state.lock:
                participants = list(self.state.participants.values())

            if not participants:
                self.stdscr.addstr(5, 2, "(No other participants)")
            else:
                for i, p in enumerate(participants):
                    y = 5 + i
                    if y >= h - 3:
                        break

                    # Selection indicator
                    prefix = "> " if i == self.state.selected_idx else "  "

                    # Name (truncated if needed)
                    name = p.name[:15]
                    attr = curses.A_REVERSE if i == self.state.selected_idx else 0

                    self.stdscr.addstr(y, 0, prefix, attr)
                    self.stdscr.addstr(y, 2, f"{name:<15}", attr)

                    # Volume bar
                    vol_pct = int(p.volume * 50)
                    vol_bar = "█" * (vol_pct // 5) + "░" * (10 - vol_pct // 5)
                    vol_str = f"[{vol_bar}] {int(p.volume * 100):3d}%"
                    self.stdscr.addstr(y, 18, vol_str)

                    # Mute status
                    mute_str = "MUTED" if p.muted else "OK"
                    mute_attr = curses.A_DIM if p.muted else 0
                    self.stdscr.addstr(y, 38, mute_str, mute_attr)

            # Help bar
            help_text = "↑↓:Select  ←→:Volume  m:Mute  M:Mute self  q:Quit"
            self.stdscr.addstr(h - 1, 0, help_text[:w-1], curses.A_DIM)

            self.stdscr.refresh()
        except curses.error:
            pass

    def handle_input(self, key: int):
        """Handle keyboard input."""
        with self.state.lock:
            participants = list(self.state.participants.values())
            num_participants = len(participants)

        if key == ord('q') or key == ord('Q'):
            self.running = False
        elif key == ord('M'):  # Mute self
            self.state.self_muted = not self.state.self_muted
        elif num_participants > 0:
            if key == curses.KEY_UP:
                self.state.selected_idx = max(0, self.state.selected_idx - 1)
            elif key == curses.KEY_DOWN:
                self.state.selected_idx = min(num_participants - 1, self.state.selected_idx + 1)
            elif key == curses.KEY_LEFT:
                # Decrease volume
                with self.state.lock:
                    if self.state.selected_idx < len(participants):
                        p = participants[self.state.selected_idx]
                        p.volume = max(0.0, p.volume - 0.1)
            elif key == curses.KEY_RIGHT:
                # Increase volume
                with self.state.lock:
                    if self.state.selected_idx < len(participants):
                        p = participants[self.state.selected_idx]
                        p.volume = min(2.0, p.volume + 0.1)
            elif key == ord('m'):
                # Toggle mute for selected participant
                with self.state.lock:
                    if self.state.selected_idx < len(participants):
                        p = participants[self.state.selected_idx]
                        p.muted = not p.muted

    async def tui_loop(self):
        """Main TUI loop."""
        self.stdscr.nodelay(True)
        self.stdscr.keypad(True)
        curses.curs_set(0)

        while self.running:
            self.draw_tui()

            try:
                key = self.stdscr.getch()
                if key != -1:
                    self.handle_input(key)
            except curses.error:
                pass

            await asyncio.sleep(0.05)  # 20 FPS

    async def run_async(self):
        """Main async entry point."""
        if not await self.connect():
            return

        loop = asyncio.get_event_loop()

        # Start mic capture thread
        mic_thread = threading.Thread(target=self.mic_capture_thread, args=(loop,), daemon=True)
        mic_thread.start()

        # Start receive loop
        receive_task = asyncio.create_task(self.receive_loop())

        # Run TUI
        await self.tui_loop()

        # Cleanup
        self.running = False
        receive_task.cancel()

        if self.mic_proc:
            self.mic_proc.terminate()

        with self.state.lock:
            for p in self.state.participants.values():
                self.stop_participant_playback(p)

        if self.writer:
            self.writer.close()
            await self.writer.wait_closed()

    def run(self, stdscr):
        """Entry point called by curses.wrapper."""
        self.stdscr = stdscr
        asyncio.run(self.run_async())


def main():
    parser = argparse.ArgumentParser(description='TUI Stream Client - Audio conference with TUI')
    parser.add_argument('server', help='Server address (host:port)')
    parser.add_argument('-n', '--name', default=os.environ.get('USER', 'anonymous'),
                        help='Your display name (default: $USER)')
    args = parser.parse_args()

    # Parse server address
    if ':' not in args.server:
        print(f"Error: Invalid server address '{args.server}'. Use host:port format.", file=sys.stderr)
        sys.exit(1)

    host, port_str = args.server.rsplit(':', 1)
    try:
        port = int(port_str)
    except ValueError:
        print(f"Error: Invalid port '{port_str}'", file=sys.stderr)
        sys.exit(1)

    client = TUIClient(host, port, args.name)
    curses.wrapper(client.run)


if __name__ == '__main__':
    main()
