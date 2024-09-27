{ config, ... }:

{
  krebs.iptables.tables.filter.INPUT.rules = [
    {
      predicate = "-p tcp --dport 139";
      target = "ACCEPT";
    }
    {
      predicate = "-p tcp --dport 445";
      target = "ACCEPT";
    }
    {
      predicate = "-p udp --dport 137";
      target = "ACCEPT";
    }
    {
      predicate = "-p udp --dport 138";
      target = "ACCEPT";
    }
  ];
  users.users.smbguest = {
    name = "smbguest";
    uid = config.ids.uids.smbguest;
    description = "smb guest user";
    home = "/home/share";
    createHome = true;
    group = "share";
  };
  users.groups.share = { };

  services.samba = {
    enable = true;
    enableNmbd = true;
    shares = {
      incoming = {
        path = "/mnt/prism";
        "read only" = "yes";
        browseable = "yes";
        "guest ok" = "yes";
      };
    };
    extraConfig = ''
      guest account = smbguest
      map to guest = bad user
      # disable printing
      load printers = no
      printing = bsd
      printcap name = /dev/null
      disable spoolss = yes
    '';
  };
}
