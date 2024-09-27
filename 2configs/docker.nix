{ pkgs, ... }:
{
  systemd.services.krebs-iptables.serviceConfig.ExecStartPost = pkgs.writeDash "kick_docker" ''
    ${pkgs.systemd}/bin/systemctl restart docker.service
  '';
}
