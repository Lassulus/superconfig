{ config, lib, pkgs, ... }:

{
  imports = [
    ./mail.nix
    ./pass.nix
  ];

  environment.systemPackages = with pkgs; [
    dic
    nmap
    git-preview
    l-gen-secrets
  ];

  services.tor.enable = true;
  services.tor.client.enable = true;

  krebs.iptables.tables.filter.INPUT.rules = [
    { predicate = "-i retiolum -p udp --dport 60000:61000"; target = "ACCEPT";}
    { predicate = "-i wiregrill -p udp --dport 60000:61000"; target = "ACCEPT";}
    { predicate = "-i retiolum -p tcp --dport 9998:9999"; target = "ACCEPT";}
    { predicate = "-i wiregrill -p tcp --dport 9998:9999"; target = "ACCEPT";}
    { predicate = "-i retiolum -p tcp --dport imap"; target = "ACCEPT";}
    { predicate = "-i wiregrill -p tcp --dport imap"; target = "ACCEPT";}
  ];

  services.dovecot2 = {
    enable = true;
    mailLocation = "maildir:~/Maildir";
  };
}
