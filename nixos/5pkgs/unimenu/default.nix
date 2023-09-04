{
  lib,
  runCommand,
  fetchurl,
  writeText,
  writers,
  coreutils,
  dmenu,
  gnused,
  libnotify,
  xclip,
  xdotool,
  gawk,
}: let
  unicode-file = runCommand "unicode.txt" {} ''
    ${
      writers.writePython3 "generate.py" {flakeIgnore = ["E501" "E722"];} ''
        import csv

        with open("${
          fetchurl {
            url = "https://unicode.org/Public/UCD/latest/ucd/UnicodeData.txt";
            sha256 = "sha256-NgGOaGV/3LNIX2NmMP/oyFMuAcl3cD0oA/W4nWxf6vs=";
          }
        }", "r") as unicode_data:
            reader = csv.reader(unicode_data, delimiter=";")
            next(reader)  # skip first row containing \0
            for row in reader:
                codepoint = row[0]
                name = row[1]
                alternate_name = row[10]
                try:
                    print(chr(int(codepoint, 16)), codepoint, name, alternate_name, sep="    ")
                except:
                    continue
      ''
    } > $out
  '';
  kaomoji-file = writeText "kaomoji.txt" ''
    ¯\(°_o)/¯    dunno lol shrug dlol
    ¯\_(ツ)_/¯    dunno lol shrug dlol
    ( ͡° ͜ʖ ͡°)    lenny
    ¯\_( ͡° ͜ʖ ͡°)_/¯    lenny shrug dlol
    ( ﾟдﾟ)    aaah sad noo
    ヽ(^o^)丿    hi yay hello
    (^o^:    ups hehe
    (^∇^)    yay
    ┗(｀皿´)┛    angry argh
    ヾ(^_^)    byebye!! bye
    <(^.^<) <(^.^)> (>^.^)> (7^.^)7 (>^.^<)    dance
    (-.-)Zzz...    sleep
    (∩╹□╹∩)    oh noes woot
    (╯°□°）╯ ┻━┻    table flip
    (」゜ロ゜)」    why woot
    (_゜_゜_)    gloom I see you
    ༼ ༎ຶ ෴ ༎ຶ༽    sad
    (\/) (°,,,,°) (\/)    krebs
    ┳━┳ ヽ(ಠل͜ಠ)ﾉ    putting table back
    ┻━┻︵ \(°□°)/ ︵ ┻━┻    flip all dem tablez
    (`･ω･´)    bear look
    ᕦ(ຈل͜ຈ)ᕤ    strong flex muscle bicep
    ᕦ(ò_óˇ)ᕤ    strong flex muscle bicep
    (๑>ᴗ<๑)    excite
    (∩ ` -´)⊃━━☆ﾟ.*･｡ﾟ    wizard spell magic
    ╰( ͡° ͜ʖ ͡° )つ──☆*:・ﾟ    wizard spell magic
    ◕ ◡ ◕    puss in boots big eye
    ≋≋≋≋≋̯̫⌧̯̫(ˆ•̮ ̮•ˆ)    nyan cat
    ʕ•ᴥ•ʔ    bear
    (ԾɷԾ)    adventure time
    (⁀ᗢ⁀)    happy yay
    (≧◡≦)    happy yay
    ＼(º □ º )/    panic
    𓂺    penis
    𓂸    penis
    __〆(￣ー￣ )    write down
    __〆(º □ º)    write down
    __〆(^_^)    write down
    C= C= C= C= C=┌(;・ω・)┘    running fast here
    ▓▒░(°◡°)░▒▓    dont care
    (๑ᵔ⤙ᵔ๑)    nom food eating
    (·•᷄ࡇ •᷅ )    ohoh sad
    ᕕ( ᐛ )ᕗ     hehe lol letsgo
    (^_~)    wink
  '';
in
  # ref https://github.com/LukeSmithxyz/voidrice/blob/9fe6802122f6e0392c7fe20eefd30437771d7f8e/.local/bin/dmenuunicode
  writers.writeDashBin "unimenu" ''
    history_file=$HOME/.cache/unimenu
    PATH=${lib.makeBinPath [coreutils dmenu gnused libnotify xclip xdotool]}
    chosen=$(cat "$history_file" ${kaomoji-file} ${unicode-file} | dmenu -p unicode -i -l 10 | tee --append "$history_file" | sed "s/    .*//")

    [ "$chosen" != "" ] || exit

    echo "$chosen" | tr -d '\n' | xclip -selection clipboard

    if [ -n "$1" ]; then
      xdotool key Shift+Insert
    else
      notify-send --app-name="$(basename "$0")" "'$chosen' copied to clipboard." &
    fi
  ''
