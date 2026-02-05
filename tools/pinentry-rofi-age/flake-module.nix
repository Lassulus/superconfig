{
  perSystem =
    { pkgs, ... }:
    {
      packages.pinentry-rofi-age = pkgs.writeShellApplication {
        name = "pinentry-rofi-age";
        runtimeInputs = with pkgs; [
          rofi
          coreutils
          gnused
          keyutils
        ];
        text = builtins.readFile ./pinentry-rofi-age.sh;
      };
    };
}
