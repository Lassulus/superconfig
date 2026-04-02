{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "pinentry-auto";
  runtimeInputs = [
    pkgs.pinentry-tty
    pkgs.pinentry-rofi
  ];
  text = builtins.readFile ./pinentry-auto.sh;
}
