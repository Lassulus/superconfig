{
  self,
  config,
  lib,
  pkgs,
  ...
}:
let
  # ANSI-terminal-style homepage, inline HTML with clickable links. The IBM
  # VGA webfont (CC BY-SA 4.0, int10h.org/oldschool-pc-fonts) is base64-inlined
  # so the page is a single self-contained file.
  webroot = pkgs.runCommand "lassul.us-webroot" { } ''
    mkdir $out
    substitute ${./lassul.us/index.html} $out/index.html \
      --replace-fail @font_woff_b64@ "$(base64 -w0 ${./lassul.us/Web437_IBM_VGA_8x16.woff})"
    cp ${./lassul.us/robots.txt} $out/robots.txt
    cp ${./lassul.us/profile.nix} $out/profile.nix
  '';
in
{
  imports = [
    ./default.nix
  ];

  security.acme = {
    defaults.email = "acme@lassul.us";
    acceptTerms = true;
    certs."lassul.us" = {
      group = "lasscert";
    };
  };

  users.groups.lasscert.members = [
    "nginx"
  ];

  services.nginx.virtualHosts."lassul.us" = {
    addSSL = true;
    enableACME = true;
    default = true;
    locations."/".extraConfig = ''
      root ${webroot};
    '';
    locations."= /profile.nix".extraConfig = ''
      root ${webroot};
      default_type text/plain;
    '';
    locations."= /wireguard-key".extraConfig = ''
      alias ${pkgs.writeText "neoprism.wg" self.inputs.kartei.hosts.neoprism.nets.wiregrill.wireguard.pubkey};
    '';
    # the keys lass logs in with, one per line
    locations."= /ssh.pub".extraConfig = ''
      alias ${pkgs.writeText "ssh.pub" (lib.concatLines config.users.users.mainUser.openssh.authorizedKeys.keys)};
    '';
    locations."= /gpg.pub".extraConfig = ''
      alias ${self.keys.pgp.yubi_pgp.key};
    '';
    locations."= /ip".extraConfig = ''
      return 200 '$remote_addr';
    '';
  };
}
