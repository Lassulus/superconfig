{ config, pkgs, ... }:
let
  host-colors = {
    mors = "131";
    prism = "95";
    uriel = "61";
    shodan = "51";
    icarus = "53";
    echelon = "197";
    cloudkrebs = "119";
  };
  urgent = [
    "\\blass@blue\\b"
  ];
in {
  environment.systemPackages = [
    (pkgs.writeDashBin "logf" ''
      export LOGF_URGENT=${pkgs.writeJSON "urgent" urgent}
      export LOGF_HOST_COLORS=${pkgs.writeJSON "host-colors" host-colors}
      ${pkgs.logf}/bin/logf ${concatMapStringsSep " " (name: "root@${name}") (attrNames config.lass.hosts)}
    '')
  ];
}
