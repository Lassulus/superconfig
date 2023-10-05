{ config, lib, pkgs, ... }: let

  vmip = "192.168.122.208";

in {
  users.users.riot = {
    uid = genid "riot";
    isNormalUser = true;
    extraGroups = [ "libvirtd" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDMkyCwdwBrsbs3qrNQcy/SqQpex4aaQoAMuT+NDefFc8KVHOMfmkDccEyAggDTgQhUrEVIvo/fFUmGBd9sm1vN1IthO2Qh5nX+qiK/A2R7sxci0Ry6piU03R27JfpZqi6g8TSPNi1C9rC8eBqOfO3OB8oQOkFmM48Q9cmS8AV3ERLR0LaHoEqUbs86JELbtHrMdKk4Hzo8zTM/isP3GO8iDHRt4dBS/03Ve7+WVxgNwWU2HW3a3jJd3tWHrqGmS/ZfCEC/47eIj4WSW+JiH9Q0BarNEbkkMV1Mvm32MX52stGPd5FaIIUtFqD4745iVSiw8esUGFUxJ1RjWgUHr99h riot@vortex"
    ];
  };

  networking.interfaces."eth0:0".ip4 = [
    {
      address = "213.239.205.246";
      prefixLength = 24;
    }
  ];

  krebs.iptables.tables.nat.PREROUTING.rules = mkBefore [
    { v6 = false; predicate = "-d 213.239.205.246 -p tcp --dport 22"; target = "DNAT --to-destination 192.168.122.208:22"; }
    { v6 = false; predicate = "-d 213.239.205.246 -p tcp --dport 25"; target = "DNAT --to-destination 192.168.122.208:25"; }
    { v6 = false; predicate = "-d 213.239.205.246 -p tcp --dport 80"; target = "DNAT --to-destination 192.168.122.208:1080"; }
    { v6 = false; predicate = "-d 213.239.205.246 -p tcp --dport 443"; target = "DNAT --to-destination 192.168.122.208:1443"; }
  ];

  krebs.iptables.tables.filter.FORWARD.rules = mkBefore [
    { v6 = false; predicate = "-d 192.168.122.208 -p tcp --dport 22 -m state --state NEW,ESTABLISHED,RELATED"; target = "ACCEPT"; }
    { v6 = false; predicate = "-d 192.168.122.208 -p tcp --dport 25 -m state --state NEW,ESTABLISHED,RELATED"; target = "ACCEPT"; }
    { v6 = false; predicate = "-d 192.168.122.208 -p tcp --dport 1080 -m state --state NEW,ESTABLISHED,RELATED"; target = "ACCEPT"; }
    { v6 = false; predicate = "-d 192.168.122.208 -p tcp --dport 1443 -m state --state NEW,ESTABLISHED,RELATED"; target = "ACCEPT"; }
  ];

  krebs.iptables.tables.nat.OUTPUT.rules = mkBefore [
    { v6 = false; predicate = "-d 213.239.205.246 -p tcp --dport 443"; target = "DNAT --to-destination 192.168.122.208:1443"; }
  ];

  # TODO use bridge interfaces instead of this crap
  systemd.services.libvirtd.serviceConfig.ExecStartPost = let
    restart-iptables = pkgs.writeDash "restart-iptables" ''
      #soo hacky
      ${pkgs.coreutils}/bin/sleep 5s
      ${pkgs.systemd}/bin/systemctl restart krebs-iptables.service
    '';
  in restart-iptables;
}
