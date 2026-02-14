#!/usr/bin/env python3
"""turbomode - Turbo/rapid-fire mode for gamepad buttons.

When enabled, holding the specified button will rapidly press and release it
instead of holding it down. All other inputs are forwarded transparently.
"""

import argparse
import sys
import threading
import time

import evdev
from evdev import UInput, ecodes

BUTTON_NAMES: dict[str, int] = {
    "a": ecodes.BTN_SOUTH,
    "b": ecodes.BTN_EAST,
    "x": ecodes.BTN_NORTH,
    "y": ecodes.BTN_WEST,
    "lb": ecodes.BTN_TL,
    "rb": ecodes.BTN_TR,
    "lt": ecodes.BTN_TL2,
    "rt": ecodes.BTN_TR2,
    "start": ecodes.BTN_START,
    "select": ecodes.BTN_SELECT,
    "thumbl": ecodes.BTN_THUMBL,
    "thumbr": ecodes.BTN_THUMBR,
}


def find_gamepad() -> evdev.InputDevice | None:
    """Find the first gamepad-like device (has both EV_KEY and EV_ABS)."""
    for path in evdev.list_devices():
        dev = evdev.InputDevice(path)
        caps = dev.capabilities()
        if ecodes.EV_KEY in caps and ecodes.EV_ABS in caps:
            return dev
    return None


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Turbo mode: hold a gamepad button for rapid-fire pressing"
    )
    parser.add_argument(
        "--button",
        required=True,
        help="button name ({}) or evdev code number".format(
            "/".join(BUTTON_NAMES.keys())
        ),
    )
    parser.add_argument(
        "--device",
        help="input device path (auto-detects gamepad if not specified)",
    )
    parser.add_argument(
        "--rate",
        type=int,
        default=30,
        help="presses per second (default: 30)",
    )
    args = parser.parse_args()

    # Resolve button code
    button_name = args.button.lower()
    if button_name in BUTTON_NAMES:
        turbo_button = BUTTON_NAMES[button_name]
    else:
        try:
            turbo_button = int(args.button)
        except ValueError:
            print(f"Unknown button: {args.button}", file=sys.stderr)
            print(
                f"Known buttons: {', '.join(BUTTON_NAMES.keys())}",
                file=sys.stderr,
            )
            sys.exit(1)

    # Open device
    if args.device:
        dev = evdev.InputDevice(args.device)
    else:
        found = find_gamepad()
        if found is None:
            print("No gamepad found", file=sys.stderr)
            sys.exit(1)
        dev = found

    print(f"Device: {dev.name} ({dev.path})")
    print(f"Turbo button: {button_name} (code {turbo_button})")
    print(f"Rate: {args.rate} presses/sec")

    # Create virtual device cloning the real one's capabilities
    ui = UInput.from_device(dev, name=f"{dev.name} (turbo)")

    # Grab the real device so its events only go through our proxy
    dev.grab()

    turbo_active = threading.Event()
    stop_event = threading.Event()

    def turbo_loop() -> None:
        # Each cycle is press + release, so we need 2x the interval
        interval = 1.0 / (args.rate * 2)
        while not stop_event.is_set():
            turbo_active.wait(timeout=1.0)
            if stop_event.is_set():
                break
            if not turbo_active.is_set():
                continue
            ui.write(ecodes.EV_KEY, turbo_button, 1)
            ui.syn()
            if stop_event.wait(timeout=interval):
                break
            if not turbo_active.is_set():
                continue
            ui.write(ecodes.EV_KEY, turbo_button, 0)
            ui.syn()
            if stop_event.wait(timeout=interval):
                break

    t = threading.Thread(target=turbo_loop, daemon=True)
    t.start()

    try:
        for event in dev.read_loop():
            if event.type == ecodes.EV_KEY and event.code == turbo_button:
                if event.value == 1:  # Pressed
                    turbo_active.set()
                elif event.value == 0:  # Released
                    turbo_active.clear()
                    # Ensure the button ends in released state
                    ui.write(ecodes.EV_KEY, turbo_button, 0)
                    ui.syn()
                # Don't forward original turbo button events
            else:
                # Forward all other events as-is
                ui.write_event(event)
    except KeyboardInterrupt:
        pass
    finally:
        stop_event.set()
        turbo_active.set()  # Wake the thread so it can exit
        dev.ungrab()
        ui.close()


if __name__ == "__main__":
    main()
