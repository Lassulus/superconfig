{
  pkgs,
  ...
}:
let
  python = pkgs.python3.withPackages (
    ps: with ps; [
      beautifulsoup4
    ]
  );
in
pkgs.writeShellApplication {
  name = "kagi-search";
  runtimeInputs = [
    python
    pkgs.rbw
  ];
  text = ''
    if ! rbw unlocked 2>/dev/null; then
      if [ -t 0 ]; then
        rbw unlock
      else
        saved_pinentry=$(rbw config show | ${pkgs.jq}/bin/jq -r '.pinentry')
        rbw config set pinentry ${pkgs.pinentry-rofi}/bin/pinentry-rofi
        trap 'rbw config set pinentry "$saved_pinentry"' EXIT
        rbw unlock
      fi
    fi
    ${python}/bin/python ${./kagi_search.py} "$@"
  '';
}
