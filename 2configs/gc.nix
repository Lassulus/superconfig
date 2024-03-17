{ config, lib, ... }:
{
  nix.gc = {
    automatic = ! (lib.elem config.krebs.build.host.name [ "aergia" "ignavia" "mors" "xerxes" "coaxmetal" ] || config.boot.isContainer);
    options = "--delete-older-than 15d";
  };
}
