{ config, pkgs, ... }:
{
  krebs.sync-containers3.containers.green = {
    sshKey = "${config.krebs.secret.directory}/green.sync.key";
  };
}
