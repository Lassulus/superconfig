{
  perSystem =
    { pkgs, self', ... }:
    let
      python = pkgs.python3.withPackages (ps: with ps; [ beautifulsoup4 ]);
      pinentry =
        if pkgs.stdenv.isDarwin then
          "${pkgs.pinentry_mac}/${pkgs.pinentry_mac.binaryPath}"
        else
          "${self'.packages.pinentry-rofi}/bin/pinentry-rofi";
    in
    {
      packages.kagi-search =
        (pkgs.writeShellApplication {
          name = "kagi-search";
          runtimeInputs = [
            python
            pkgs.rbw
          ];
          text = ''
            if ! rbw unlocked 2>/dev/null; then
              rbw config set pinentry ${pinentry}
              rbw unlock
            fi
            ${python}/bin/python ${./kagi_search.py} "$@"
          '';
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
