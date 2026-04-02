{
  pkgs,
  pinentry-auto ? pkgs.callPackage ../pinentry-auto/package.nix { },
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
      rbw config set pinentry ${pinentry-auto}/bin/pinentry-auto
      rbw unlock
    fi
    ${python}/bin/python ${./kagi_search.py} "$@"
  '';
}
