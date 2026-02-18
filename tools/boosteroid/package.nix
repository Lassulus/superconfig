{
  lib,
  stdenv,
  fetchurl,
  buildFHSEnv,
  writeShellScript,
  # runtime deps
  alsa-lib,
  dbus,
  fontconfig,
  freetype,
  libGL,
  libX11,
  libxcb,
  libXfixes,
  libXi,
  libva,
  libvdpau,
  libxkbcommon,
  numactl,
  pcre2,
  pulseaudio,
  systemd,
  wayland,
  xcb-util-cursor,
  libxrender,
  libxcb-util,
  libxcb-image,
  libxcb-keysyms,
  libxcb-render-util,
  libxcb-wm,
}:

let
  pname = "boosteroid";
  version = "1.0.0";

  src = fetchurl {
    url = "https://boosteroid.com/linux/installer/boosteroid_portable.tar";
    hash = "sha256-xXpFD9dzHbakOqOIQ1sqzmGRo49EYbVqHZT0nGvRPcI=";
  };

  unwrapped = stdenv.mkDerivation {
    inherit pname version src;
    sourceRoot = ".";
    unpackCmd = "tar xf $curSrc";
    installPhase = ''
      install -Dm755 Boosteroid $out/bin/Boosteroid
    '';
  };
in
buildFHSEnv {
  name = "boosteroid";

  targetPkgs = _: [
    unwrapped
    alsa-lib
    dbus
    fontconfig
    freetype
    libGL
    libX11
    libxcb
    libXfixes
    libXi
    libva
    libvdpau
    libxkbcommon
    numactl
    pcre2
    pulseaudio
    systemd # libudev
    wayland
    xcb-util-cursor
    libxrender
    libxcb-util
    libxcb-image
    libxcb-keysyms
    libxcb-render-util
    libxcb-wm
  ];

  runScript = writeShellScript "boosteroid-wrapper" ''
    dir="''${XDG_DATA_HOME:-$HOME/.local/share}/boosteroid"
    mkdir -p "$dir"
    # Boosteroid writes logs next to its binary (via /proc/self/exe),
    # so we copy it to a writable directory
    bin="$(command -v Boosteroid)"
    if [ ! -x "$dir/Boosteroid" ] || ! cmp -s "$bin" "$dir/Boosteroid"; then
      cp "$bin" "$dir/Boosteroid"
      chmod +x "$dir/Boosteroid"
    fi
    cd "$dir"
    exec "$dir/Boosteroid" "$@"
  '';

  meta = {
    description = "Boosteroid cloud gaming client";
    homepage = "https://boosteroid.com";
    # proprietary but freely downloadable, using lib.licenses.free to avoid --impure
    license = lib.licenses.free;
    platforms = [ "x86_64-linux" ];
    mainProgram = "boosteroid";
  };
}
