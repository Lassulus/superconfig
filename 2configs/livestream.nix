{ pkgs, ... }:

let

  stream = pkgs.writeDashBin "stream" ''
    ${pkgs.python27Packages.livestreamer}/bin/livestreamer --http-header Client-ID=jzkbprff40iqj646a697cyrvl0zt2m6 -p mpv "$@"
  '';

in
{
  environment.systemPackages = [ stream ];
}
