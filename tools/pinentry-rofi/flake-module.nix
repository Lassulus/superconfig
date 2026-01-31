{
  perSystem =
    { pkgs, ... }:
    {
      packages.pinentry-rofi = pkgs.writeShellApplication {
        name = "pinentry-rofi";
        runtimeInputs = with pkgs; [
          rofi
          coreutils
          gnused
          keyutils
        ];
        text = builtins.readFile ./pinentry-rofi.sh;
      };
    };
}
