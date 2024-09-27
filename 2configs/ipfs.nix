{ pkgs, ... }:
{
  services.ipfs = {
    enable = true;
  };
  users.users.mainUser.extraGroups = [ "ipfs" ];
  systemd.services.ipfs.serviceConfig.ExecStartPost = [
    (pkgs.writers.writeDash "fix-permission" ''
      chmod g+r /var/lib/ipfs/config
    '')
  ];
}
