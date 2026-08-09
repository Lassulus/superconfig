{ inputs, ... }:
{
  perSystem =
    { pkgs, lib, ... }:
    let
      # nnn's nerd icon table hardcodes xterm-256 colours, which would be the
      # one part of the UI that ignores the terminal theme. Remap them onto the
      # ANSI palette; 0 means "use the file's own colour".
      iconColors = {
        COLOR_ARCHIVE = 1;
        COLOR_AUDIO = 3;
        COLOR_AUDIO1 = 13;
        COLOR_C = 12;
        COLOR_CSS = 5;
        COLOR_DOCS = 9;
        COLOR_DOCUMENT = 0;
        COLOR_ELIXIR = 5;
        COLOR_FSHARP = 6;
        COLOR_IMAGE = 10;
        COLOR_JAVA = 4;
        COLOR_JAVASCRIPT = 3;
        COLOR_LUA = 4;
        COLOR_PYTHON = 11;
        COLOR_REACT = 14;
        COLOR_RUBY = 1;
        COLOR_SCALA = 9;
        COLOR_SHELL = 2;
        COLOR_VIDEO = 14;
        COLOR_VIDEO1 = 11;
        COLOR_VIM = 2;
      };

      # Anything outside 0-15 left in the table means nnn grew an icon colour
      # we have not mapped, so fail the build instead of shipping a stray hue.
      unmapped = "COLOR_X\\(COLOR_[A-Z0-9_]+, *(1[6-9]|[2-9][0-9]|[0-9]{3})\\)";

      nnn = (pkgs.nnn.override { withNerdIcons = true; }).overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          sed -i -E ${
            lib.concatStringsSep " " (
              lib.mapAttrsToList (
                name: code: "-e 's/COLOR_X\\(${name},[^)]*\\)/COLOR_X(${name}, ${toString code})/'"
              ) iconColors
            )
          } src/icons.h
          if grep -nE '${unmapped}' src/icons.h; then
            echo "nnn icon colours above are outside the ANSI palette" >&2
            exit 1
          fi
        '';
      });

      # Asks the terminal which graphics protocol it speaks. Run once per nnn
      # session so no image preview has to wait on a terminal round trip.
      term-caps = pkgs.writeShellApplication {
        name = "nnn-term-caps";
        runtimeInputs = [ pkgs.coreutils ];
        text = builtins.readFile ./term-caps.sh;
      };

      imgpreview = pkgs.writeShellApplication {
        name = "nnn-imgpreview";
        runtimeInputs = [
          pkgs.chafa
          pkgs.coreutils
        ];
        text = builtins.readFile ./imgpreview.sh;
      };

      # Tools the preview/open plugins probe for at runtime. They are prefixed
      # onto $PATH rather than replacing it, so a tmux/kitty already in the
      # environment stays reachable.
      pluginTools = [
        imgpreview
        pkgs.bat
        pkgs.coreutils
        pkgs.exiftool
        pkgs.fd
        pkgs.ffmpegthumbnailer
        pkgs.file
        pkgs.findutils
        pkgs.fzf
        pkgs.gnutar
        pkgs.jq
        pkgs.less
        pkgs.libarchive
        pkgs.librsvg
        pkgs.mdcat
        pkgs.mediainfo
        pkgs.ncurses
        pkgs.poppler-utils
        pkgs.procps
        pkgs.tree
        pkgs.unzip
        pkgs.viu
        pkgs.w3m
      ];

      # nnn resolves bare plugin names inside $XDG_CONFIG_HOME/nnn/plugins,
      # which we do not own, so the plugins live here and are referenced by
      # absolute path from NNN_PLUG.
      plugins =
        let
          pathLine = ''export PATH="${lib.makeBinPath pluginTools}:$PATH"'';
        in
        pkgs.runCommand "nnn-plugins" { } ''
          mkdir -p $out/libexec/nnn
          cp ${nnn}/share/plugins/.nnn-plugin-helper $out/libexec/nnn/
          for plugin in preview-tui fzcd fzopen nuke; do
            install -m755 ${nnn}/share/plugins/"$plugin" $out/libexec/nnn/"$plugin"
            sed -i '2i ${pathLine}' $out/libexec/nnn/"$plugin"
          done

          # glow renders markdown with a fixed hex palette and, as of 2.1.2,
          # emits no colour at all outside a tty. mdcat renders to plain ANSI
          # attributes, so markdown previews follow the terminal like the rest.
          substituteInPlace $out/libexec/nnn/preview-tui \
            --replace-fail 'md) if exists glow; then' 'md) if exists mdcat; then' \
            --replace-fail 'fifo_pager glow -s dark "$1"' 'fifo_pager mdcat --columns "$cols" "$1"'
          substituteInPlace $out/libexec/nnn/nuke \
            --replace-fail 'if type glow >/dev/null 2>&1; then' 'if type mdcat >/dev/null 2>&1; then' \
            --replace-fail 'glow -sdark "''${FPATH}" | eval "$PAGER"' 'mdcat "''${FPATH}" | eval "$PAGER"'

          # NNN_IMGFORMAT is decided before nnn starts, and preview-tui only
          # forwards the variables on this list into the preview pane.
          substituteInPlace $out/libexec/nnn/preview-tui \
            --replace-fail \
              '"NNN_PREVIEWIMGPROG=''${NNN_PREVIEWIMGPROG:-}"' \
              '"NNN_PREVIEWIMGPROG=''${NNN_PREVIEWIMGPROG:-}" "NNN_IMGFORMAT=''${NNN_IMGFORMAT:-symbols}"'
        '';

      # Every colour below is an xterm-256 index in 0x00-0x0f, i.e. an entry of
      # the terminal's own ANSI palette. Retheming the terminal - including
      # switch-theme repainting a local kitty while nnn runs on the far end of
      # an ssh session - recolours nnn without nnn or the remote host being
      # involved at all.
      #
      # Order is fixed, see nnn(1) NNN_FCOLORS.
      fileColors = lib.concatStrings [
        "0b" # block device      bright yellow
        "0b" # char device       bright yellow
        "0c" # directory         bright blue
        "0a" # executable        bright green
        "00" # regular file      terminal default
        "05" # hard link         magenta
        "0e" # symlink           bright cyan
        "08" # file details      bright black
        "09" # orphaned symlink  bright red
        "03" # fifo              yellow
        "0d" # socket            bright magenta
        "01" # unknown / empty   red
      ];

      # 8 contexts as 256-colour indices, with the 8-colour fallback after ';'
      # for terminals that never report 256 colour support.
      contextColors = "#0c0a0d0e0b090605;42563165";
    in
    {
      packages.nnn = inputs.wrappers.lib.wrapPackage {
        inherit pkgs;
        package = nnn;
        aliases = [ "n" ];
        runtimeInputs = [ term-caps ];
        env = {
          NNN_FCOLORS = fileColors;
          NNN_COLORS = contextColors;
          # bat ships an "ansi" theme that only emits palette colours
          NNN_BATTHEME = "ansi";
          NNN_BATSTYLE = "numbers";
          NNN_OPENER = "${plugins}/libexec/nnn/nuke";
          NNN_PREVIEWIMGPROG = lib.getExe imgpreview;
          NNN_PLUG = lib.concatStringsSep ";" [
            "p:${plugins}/libexec/nnn/preview-tui"
            "f:${plugins}/libexec/nnn/fzcd"
            "o:${plugins}/libexec/nnn/fzopen"
          ];
        };
        preHook = ''
          # Ask the terminal once, on a tty nothing else is drawing on yet.
          NNN_IMGFORMAT=$(nnn-term-caps)
          export NNN_IMGFORMAT

          # nuke only reaches for graphical applications when a display exists.
          if [ -n "''${WAYLAND_DISPLAY:-}" ] || [ -n "''${DISPLAY:-}" ]; then
            export GUI=1
          fi

          # preview-tui splits the current pane; with no multiplexer and no
          # remote-controllable terminal it falls back to spawning $NNN_TERMINAL
          # (xterm), which is useless over ssh. Only auto-open the preview where
          # it can actually split.
          nnn_extra=()
          if [ -n "''${TMUX:-}" ] || [ -n "''${KITTY_LISTEN_ON:-}" ] ||
            [ -n "''${WEZTERM_PANE:-}" ] || [ -n "''${ZELLIJ:-}" ]; then
            nnn_extra+=(-P p)
          fi
        '';
        # -a: auto NNN_FIFO for the preview plugin, -c: NNN_OPENER is cli-only
        wrapper =
          {
            exePath,
            envString,
            preHook,
            ...
          }:
          ''
            ${envString}
            ${preHook}
            exec ${exePath} -a -c "''${nnn_extra[@]}" "$@"
          '';
      };
    };
}
