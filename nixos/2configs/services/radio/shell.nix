{ pkgs ? import <nixpkgs> {} }:
pkgs.mkShell {
  buildInputs = [
    pkgs.liquidsoap
    pkgs.yt-dlp
  ];
}
