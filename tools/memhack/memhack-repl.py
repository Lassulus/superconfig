"""memhack - memory editor with multi-type scan, freeze, and narrow"""

import os
import readline  # noqa: F401 - enables line editing in input()
import struct
import sys
import threading
import time

TYPES = {
    "i8": (1, "<B"),
    "i16": (2, "<H"),
    "i32": (4, "<I"),
    "i64": (8, "<Q"),
    "f32": (4, "<f"),
    "f64": (8, "<d"),
}

AUTO_SCAN_TYPES = ["i32", "i64", "f32", "f64"]


def parse_addr(s):
    """Parse address as hex (0x prefix optional)."""
    return int(s.removeprefix("0x").removeprefix("0X"), 16)


def parse_value(s, type_name="i32"):
    """Parse value as int or float depending on type."""
    if type_name.startswith("f"):
        return float(s)
    return int(s, 0)


def pack_value(value_str, type_name):
    """Pack a value string into bytes for the given type."""
    _, fmt = TYPES[type_name]
    if type_name.startswith("f"):
        return struct.pack(fmt, float(value_str))
    return struct.pack(fmt, int(float(value_str)))


def get_regions(pid):
    """Parse /proc/<pid>/maps for writable memory regions."""
    regions = []
    with open(f"/proc/{pid}/maps") as f:
        for line in f:
            parts = line.split()
            perms = parts[1]
            if "r" not in perms or "w" not in perms:
                continue
            addr_range = parts[0].split("-")
            start = int(addr_range[0], 16)
            end = int(addr_range[1], 16)
            regions.append((start, end))
    return regions


def type_counts(matches):
    """Count matches per type."""
    counts = {}
    for _, tn in matches:
        counts[tn] = counts.get(tn, 0) + 1
    return counts


class MemHack:
    def __init__(self, pid):
        self.pid = pid
        self.mem_path = f"/proc/{pid}/mem"
        self.mem_fd = None
        self.matches = []  # list of (addr, type_name)
        self.frozen = {}  # addr -> (value, type_name, stop_event, thread)
        self.write_error = None

    def open_mem(self):
        """Open /proc/<pid>/mem with read-write access (unbuffered)."""
        if self.mem_fd is None:
            self.mem_fd = os.open(self.mem_path, os.O_RDWR)

    def close_mem(self):
        if self.mem_fd is not None:
            os.close(self.mem_fd)
            self.mem_fd = None

    def read_value(self, addr, type_name="i32"):
        size, fmt = TYPES[type_name]
        try:
            self.open_mem()
            data = os.pread(self.mem_fd, size, addr)
            return struct.unpack(fmt, data)[0]
        except OSError:
            return None

    def write_value(self, addr, value, type_name="i32"):
        _, fmt = TYPES[type_name]
        try:
            self.open_mem()
            os.pwrite(self.mem_fd, struct.pack(fmt, value), addr)
            return True
        except (OSError, struct.error) as e:
            self.write_error = str(e)
            return False

    def scan(self, value_str, type_name=None):
        """Scan all writable memory regions for value."""
        # determine which types to scan
        if type_name:
            scan_types = [type_name]
        else:
            num = float(value_str)
            is_whole = num % 1 == 0
            scan_types = []
            if is_whole:
                scan_types.extend(["i32", "i64"])
            scan_types.extend(["f32", "f64"])

        # build packed targets per type
        targets = {}
        for tn in scan_types:
            try:
                targets[tn] = pack_value(value_str, tn)
            except (struct.error, OverflowError, ValueError):
                continue

        regions = get_regions(self.pid)
        matches = []
        bytes_scanned = 0
        t0 = time.monotonic()

        self.open_mem()
        for start, end in regions:
            try:
                data = os.pread(self.mem_fd, end - start, start)
                bytes_scanned += len(data)
                for tn, target in targets.items():
                    offset = 0
                    while True:
                        idx = data.find(target, offset)
                        if idx == -1:
                            break
                        matches.append((start + idx, tn))
                        offset = idx + 1
            except OSError:
                continue

        elapsed = time.monotonic() - t0
        self.matches = matches
        mb = bytes_scanned / (1024 * 1024)
        counts = type_counts(matches)
        breakdown = "  ".join(f"{tn}:{n}" for tn, n in counts.items())
        print(f"  {len(matches)} matches (scanned {mb:.0f} MB in {elapsed:.2f}s)")
        if breakdown:
            print(f"  {breakdown}")

    def narrow(self, value_str):
        """Re-check existing matches for a new value."""
        if not self.matches:
            print("  no matches to narrow (run scan first)")
            return
        remaining = []

        self.open_mem()
        for addr, tn in self.matches:
            try:
                target = pack_value(value_str, tn)
            except (struct.error, OverflowError, ValueError):
                continue
            size = TYPES[tn][0]
            try:
                data = os.pread(self.mem_fd, size, addr)
                if data == target:
                    remaining.append((addr, tn))
            except OSError:
                continue

        self.matches = remaining
        counts = type_counts(remaining)
        breakdown = "  ".join(f"{tn}:{n}" for tn, n in counts.items())
        print(f"  {len(remaining)} matches remaining")
        if breakdown:
            print(f"  {breakdown}")
        if 0 < len(remaining) <= 20:
            for addr, tn in remaining:
                val = self.read_value(addr, tn)
                print(f"    {hex(addr)} = {val} ({tn})")

    def set_matches(self, value_str):
        """Write value to all current matches."""
        if not self.matches:
            print("  no matches (run scan first)")
            return
        count = 0
        for addr, tn in self.matches:
            v = float(value_str) if tn.startswith("f") else int(float(value_str))
            if self.write_value(addr, v, tn):
                count += 1
        print(f"  set {count}/{len(self.matches)} addresses to {value_str}")

    def freeze(self, addr, value, type_name="i32"):
        if addr in self.frozen:
            self.unfreeze(addr, quiet=True)

        # test write first to catch errors immediately
        self.write_error = None
        if not self.write_value(addr, value, type_name):
            print(f"  write failed for {hex(addr)}: {self.write_error}")
            return

        stop = threading.Event()

        def loop():
            while not stop.is_set():
                self.write_value(addr, value, type_name)
                stop.wait(0.01)

        t = threading.Thread(target=loop, daemon=True)
        t.start()
        self.frozen[addr] = (value, type_name, stop, t)
        print(f"  frozen {hex(addr)} = {value} ({type_name})")

    def freeze_matches(self, value_str):
        """Freeze all current matches to a value."""
        if not self.matches:
            print("  no matches (run scan first)")
            return
        for addr, tn in self.matches:
            v = float(value_str) if tn.startswith("f") else int(float(value_str))
            self.freeze(addr, v, tn)

    def unfreeze(self, addr, quiet=False):
        if addr in self.frozen:
            _, _, stop, t = self.frozen.pop(addr)
            stop.set()
            t.join(timeout=1)
            if not quiet:
                print(f"  unfrozen {hex(addr)}")
        elif not quiet:
            print(f"  {hex(addr)} is not frozen")

    def unfreeze_all(self):
        for addr in list(self.frozen):
            self.unfreeze(addr)

    def show_matches(self):
        if not self.matches:
            print("  no matches")
            return
        if len(self.matches) > 20:
            counts = type_counts(self.matches)
            breakdown = "  ".join(f"{tn}:{n}" for tn, n in counts.items())
            print(f"  {len(self.matches)} matches (narrow further to see addresses)")
            print(f"  {breakdown}")
            return
        for addr, tn in self.matches:
            val = self.read_value(addr, tn)
            frozen = " [frozen]" if addr in self.frozen else ""
            print(f"  {hex(addr)} = {val} ({tn}){frozen}")

    def show_frozen(self):
        if not self.frozen:
            print("  no frozen addresses")
            return
        for addr, (value, type_name, _, _) in self.frozen.items():
            current = self.read_value(addr, type_name)
            cur_str = str(current) if current is not None else "?"
            print(f"  {hex(addr)}  frozen={value}  current={cur_str}  ({type_name})")

    def print_help(self):
        print("""commands:
  scan VALUE [TYPE]        scan memory (auto-detects i32/i64/f32/f64)
  narrow VALUE             narrow matches to new value
  list                     show current matches
  set VALUE                write value to all matches (once)
  freeze VALUE             freeze all matches to value
  freeze ADDR VALUE [TYPE] freeze specific address
  unfreeze ADDR            stop freezing address
  unfreeze all             stop all freezes
  frozen                   show frozen addresses
  read ADDR [TYPE]         read value at address
  write ADDR VALUE [TYPE]  write value to address (once)
  help                     show this help
  quit                     exit

types: i8 i16 i32 i64 f32 f64 (scan auto-detects if omitted)
addresses are always hex (0x prefix optional)

workflow: scan 100 → take damage → narrow 95 → repeat → freeze 999""")

    def repl(self):
        print(f"memhack attached to PID {self.pid}")
        print('type "help" for commands, "scan VALUE" to start searching')
        print()

        while True:
            try:
                tags = []
                if self.matches:
                    tags.append(f"{len(self.matches)} matches")
                if self.frozen:
                    tags.append(f"{len(self.frozen)} frozen")
                tag = f" [{', '.join(tags)}]" if tags else ""
                line = input(f"memhack{tag}> ").strip()
            except (EOFError, KeyboardInterrupt):
                print()
                break

            if not line:
                continue

            parts = line.split()
            cmd = parts[0].lower()

            try:
                if cmd == "scan":
                    if len(parts) < 2:
                        print("  usage: scan VALUE [TYPE]")
                        continue
                    type_name = parts[2] if len(parts) > 2 else None
                    if type_name and type_name not in TYPES:
                        print(f"  unknown type: {type_name}")
                        continue
                    self.scan(parts[1], type_name)
                elif cmd == "narrow":
                    if len(parts) < 2:
                        print("  usage: narrow VALUE")
                        continue
                    self.narrow(parts[1])
                elif cmd == "list":
                    self.show_matches()
                elif cmd == "set":
                    if len(parts) < 2:
                        print("  usage: set VALUE")
                        continue
                    self.set_matches(parts[1])
                elif cmd == "freeze":
                    if len(parts) == 2:
                        self.freeze_matches(parts[1])
                    elif len(parts) >= 3:
                        type_name = parts[3] if len(parts) > 3 else "i32"
                        if type_name not in TYPES:
                            print(f"  unknown type: {type_name}")
                            continue
                        self.freeze(
                            parse_addr(parts[1]),
                            parse_value(parts[2], type_name),
                            type_name,
                        )
                    else:
                        print("  usage: freeze VALUE | freeze ADDR VALUE [TYPE]")
                elif cmd == "unfreeze":
                    if len(parts) < 2:
                        print("  usage: unfreeze ADDR | unfreeze all")
                    elif parts[1] == "all":
                        self.unfreeze_all()
                    else:
                        self.unfreeze(parse_addr(parts[1]))
                elif cmd == "frozen":
                    self.show_frozen()
                elif cmd == "read":
                    if len(parts) < 2:
                        print("  usage: read ADDR [TYPE]")
                        continue
                    type_name = parts[2] if len(parts) > 2 else "i32"
                    val = self.read_value(parse_addr(parts[1]), type_name)
                    if val is not None:
                        print(f"  {val}")
                elif cmd == "write":
                    if len(parts) < 3:
                        print("  usage: write ADDR VALUE [TYPE]")
                        continue
                    type_name = parts[3] if len(parts) > 3 else "i32"
                    addr = parse_addr(parts[1])
                    val = parse_value(parts[2], type_name)
                    if self.write_value(addr, val, type_name):
                        print(f"  wrote {parts[2]} to {hex(addr)}")
                elif cmd in ("quit", "exit", "q"):
                    break
                elif cmd == "help":
                    self.print_help()
                else:
                    print(f'  unknown command: "{cmd}" (type "help")')
            except (ValueError, IndexError) as e:
                print(f"  error: {e}")

        self.unfreeze_all()
        self.close_mem()


def main():
    if len(sys.argv) < 2:
        print("usage: memhack-repl PID", file=sys.stderr)
        sys.exit(1)

    pid = int(sys.argv[1])

    if not os.path.exists(f"/proc/{pid}"):
        print(f"process {pid} not found", file=sys.stderr)
        sys.exit(1)

    MemHack(pid).repl()


if __name__ == "__main__":
    main()
