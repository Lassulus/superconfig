import subprocess
import threading
import json
import os
from typing import Callable

from libqtile import bar, layout, widget, extension, hook
from libqtile.config import Click, Drag, Group, Key, Match, Screen, ScratchPad, DropDown
from libqtile.lazy import lazy
from libqtile.utils import guess_terminal
from libqtile.command.client import InteractiveCommandClient
from libqtile.core.manager import Qtile
from libqtile.backend.wayland import InputConfig

prompt = widget.Prompt()
state_file = "/home/lass/.local/share/qtile/state"


def dmenu(candidates: list[str], callback: Callable) -> None:
    def thread() -> None:
        dmenu = subprocess.Popen(["rofi", "-dmenu"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        output = dmenu.communicate(input=("\n".join(candidates)).encode())
        callback(output[0].decode().rstrip())
    threading.Thread(target=thread).start()

@lazy.function
def goto_workspace(qtile: Qtile) -> None:
    def callback(name: str) -> None:
        c=InteractiveCommandClient()
        c.group[name].toscreen()
    dmenu(candidates=qtile.items("group")[1], callback=callback)

@lazy.function
def moveto_workspace(qtile: Qtile) -> None:
    def callback(name: str) -> None:
        c=InteractiveCommandClient()
        c.window.togroup(name)
    dmenu(candidates=qtile.items("group")[1], callback=callback)

@lazy.function
def add_group(qtile: Qtile) -> None:
    def callback(name: str) -> None:
        qtile.addgroup(name)
    prompt.start_input("Add group: ", callback=callback)

@lazy.function
def del_group(qtile: Qtile) -> None:
    qtile.delgroup(qtile.current_group.name)

@lazy.function
def reload_config(qtile: Qtile) -> None:
    with open(state_file, "w") as f:
        f.write(json.dumps(qtile.get_groups(), default=tuple))
    qtile.reload_config()

mod = "mod4"
terminal = guess_terminal()

if os.path.exists(state_file):
    with open(state_file, "r") as f:
        state = json.loads(f.read())
        groups = [Group(name) for name, _ in state.items()]
else:
    groups = [
            Group("dashboard"),
            Group("ff"),
    ]

keys = [
    # A list of available commands that can be bound to keys can be found
    # at https://docs.qtile.org/en/latest/manual/config/lazy.html
    # Switch between windows
    Key([mod], "Tab", lazy.layout.next(), desc="Move window focus to other window"),
    Key([mod, "shift"], "Tab", lazy.layout.previous(), desc="Move window focus to other window"),

    Key([mod], "Escape", lazy.screen.toggle_group(), desc="Switch to last active group"),
    # Move windows between left/right columns or move up/down in current stack.
    # Moving out of range in Columns layout will create new column.
    Key([mod, "shift"], "a", add_group, desc="add group"),
    Key([mod, "shift"], "backspace", del_group, desc="delete group"),
    Key([mod, "shift"], "h", lazy.layout.shuffle_left(), desc="Move window to the left"),
    Key([mod, "shift"], "l", lazy.layout.shuffle_right(), desc="Move window to the right"),
    Key([mod, "shift"], "j", lazy.layout.shuffle_down(), desc="Move window down"),
    Key([mod, "shift"], "k", lazy.layout.shuffle_up(), desc="Move window up"),
    # Grow windows. If current window is on the edge of screen and direction
    # will be to screen edge - window would shrink.
    Key([mod, "control"], "h", lazy.layout.grow_left(), desc="Grow window to the left"),
    Key([mod, "control"], "l", lazy.layout.grow_right(), desc="Grow window to the right"),
    Key([mod, "control"], "j", lazy.layout.grow_down(), desc="Grow window down"),
    Key([mod, "control"], "k", lazy.layout.grow_up(), desc="Grow window up"),
    Key([mod], "f", lazy.window.toggle_fullscreen(), desc="Toggle fullscreen",),
    Key([mod], "n", lazy.layout.normalize(), desc="Reset all window sizes"),
    Key([mod], "d", lazy.spawn("copyq show")),
    Key([mod, "shift"], "Return", lazy.spawn(terminal), desc="Launch terminal"),
    # Toggle between different layouts as defined below
    Key([mod], "Space", lazy.next_layout(), desc="Toggle between layouts"),
    Key([mod, "shift"], "c", lazy.window.kill(), desc="Kill focused window"),
    Key([mod], "F11", lazy.spawn("swaylock --image /var/lib/wallpaper/wallpaper")),
    Key([mod], "t", lazy.window.toggle_floating(), desc="Toggle floating on the focused window"),
    Key([mod, "shift"], "r", reload_config, desc="Reload the config"),
    Key([mod, "control"], "q", lazy.shutdown(), desc="Shutdown Qtile"),
    Key([mod], "r", lazy.spawncmd(), desc="Spawn a command using a prompt widget"),
    Key([mod], "F1", lazy.group["scratchpad"].dropdown_toggle("term")),
    Key([mod], "i", lazy.spawn("screenshot")),
    Key([mod], "p", lazy.spawn("pass_menu")),
    Key([mod], "Insert", lazy.spawn("type_paste")),
    Key([mod, "shift"], "p", lazy.spawn("otpmenu")),
    Key([mod], "v", goto_workspace, desc="Switch to group"),
    Key([mod, "shift"], "v", moveto_workspace, desc="move window to group"),
    Key([], "XF86AudioRaiseVolume", lazy.spawn("pactl set-sink-volume @DEFAULT_SINK@ +5%")),
    Key([], "XF86AudioLowerVolume", lazy.spawn("pactl set-sink-volume @DEFAULT_SINK@ -5%")),
    Key([], "XF86MonBrightnessUp", lazy.spawn("xbacklight -inc 2")),
    Key([], "XF86MonBrightnessDown", lazy.spawn("xbacklight -dec 2")),

    Key(["control", "mod1"], "F1", lazy.core.change_vt(1), desc="Switch to VT 1"),
    Key(["control", "mod1"], "F2", lazy.core.change_vt(2), desc="Switch to VT 2"),
    Key(["control", "mod1"], "F3", lazy.core.change_vt(3), desc="Switch to VT 3"),
    Key(["control", "mod1"], "F4", lazy.core.change_vt(4), desc="Switch to VT 4"),
    Key(["control", "mod1"], "F5", lazy.core.change_vt(5), desc="Switch to VT 5"),
    Key(["control", "mod1"], "F6", lazy.core.change_vt(6), desc="Switch to VT 6"),
]

layouts = [
    layout.Max(),
    layout.Columns(border_focus_stack=["#d75f5f", "#8f3d3d"], border_width=4),
    # Try more layouts by unleashing below layouts.
    # layout.Stack(num_stacks=2),
    # layout.Bsp(),
    layout.Matrix(),
    # layout.MonadTall(),
    # layout.MonadWide(),
    # layout.RatioTile(),
    # layout.Tile(),
    # layout.TreeTab(),
    # layout.VerticalTile(),
    # layout.Zoomy(),
]

widget_defaults = dict(
    font="sans",
    fontsize=12,
    padding=3,
)
extension_defaults = widget_defaults.copy()

screens = [
    Screen(
        bottom=bar.Bar(
            [
                widget.CurrentLayout(),
                widget.GenPollUrl(
                    url="http://radio.r:8002/current",
                    parse=lambda r: "/".join(r["filename"].split("/")[-2:]),
                    update_interval=15,
                ),
                widget.Spacer(),
                widget.Wlan(interface="wlp170s0"),
                widget.HDDBusyGraph(device="nvme0n1", graph_color="#4fbe4f"),
                widget.MemoryGraph(graph_color="#eed563"),
                widget.CPUGraph(graph_color="#8575bf"),
                widget.ThermalZone(zone="/sys/class/thermal/thermal_zone1/temp", background="#440000"),
                widget.PulseVolume(background="#009900"),
                widget.Backlight(background="#b18f00", backlight_name="intel_backlight"),
                widget.Battery(background="#e52383"),
                widget.Clock(format="%Y-%m-%d %a %H:%M"),
                # NB Systray is incompatible with Wayland, consider using StatusNotifier instead
                widget.StatusNotifier(),
            ],
            24,
            # border_width=[2, 0, 2, 0],  # Draw top and bottom borders
            # border_color=["ff00ff", "000000", "ff00ff", "000000"]  # Borders are magenta
        ),
        top=bar.Bar(
            [
                widget.GroupBox(),
                prompt,
                widget.WindowName(),
                widget.Chord(
                    chords_colors={
                        "launch": ("#ff0000", "#ffffff"),
                    },
                    name_transform=lambda name: name.upper(),
                ),
            ],
            24,
        ),
        # You can uncomment this variable if you see that on X11 floating resize/moving is laggy
        # By default we handle these events delayed to already improve performance, however your system might still be struggling
        # This variable is set to None (no cap) by default, but you can set it to 60 to indicate that you limit it to 60 events per second
        # x11_drag_polling_rate = 60,
    ),
]

# Drag floating layouts.
mouse = [
    Drag([mod], "Button1", lazy.window.set_position_floating(), start=lazy.window.get_position()),
    Drag([mod], "Button3", lazy.window.set_size_floating(), start=lazy.window.get_size()),
    Click([mod], "Button2", lazy.window.bring_to_front()),
]

dgroups_key_binder = None
dgroups_app_rules = []  # type: list
follow_mouse_focus = True
bring_front_click = False
floats_kept_above = True
cursor_warp = False
floating_layout = layout.Floating(
    float_rules=[
        # Run the utility of `xprop` to see the wm class and name of an X client.
        *layout.Floating.default_float_rules,
        Match(wm_class="confirmreset"),  # gitk
        Match(wm_class="makebranch"),  # gitk
        Match(wm_class="maketag"),  # gitk
        Match(wm_class="ssh-askpass"),  # ssh-askpass
        Match(title="branchdialog"),  # gitk
        Match(title="pinentry"),  # GPG key password entry
    ]
)
auto_fullscreen = True
focus_on_window_activation = "smart"
reconfigure_screens = True

# If things like steam games want to auto-minimize themselves when losing
# focus, should we respect this or not?
auto_minimize = True

# When using the Wayland backend, this can be used to configure input devices.
wl_input_rules = {
    "type:keyboard": InputConfig(kb_options="ctrl:nocaps", kb_layout="us", kb_variant="altgr-intl"),
}

@hook.subscribe.startup
def autostart():
    subprocess.run(
        [
            "systemctl",
            "--user",
            "import-environment",
            "XDG_SESSION_PATH",
            "WAYLAND_DISPLAY",
        ]
    )

# XXX: Gasp! We're lying here. In fact, nobody really uses or cares about this
# string besides java UI toolkits; you can see several discussions on the
# mailing lists, GitHub issues, and other WM documentation that suggest setting
# this string if your java app doesn't work correctly. We may as well just lie
# and say that we're a working one by default.
#
# We choose LG3D to maximize irony: it is a 3D non-reparenting WM written in
# java that happens to be on java's whitelist.
wmname = "LG3D"
