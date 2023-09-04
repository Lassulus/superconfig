{ config, lib, pkgs, ... }:
{
  systemd.tmpfiles.rules = [
    "L+ /var/lib/hass/custom_components/pyscript - - - - ${pkgs.fetchzip {
      url = "https://github.com/custom-components/pyscript/releases/download/1.3.2/hass-custom-pyscript.zip";
      sha256 = "0cqdjj46s5xp4mqxb0ic790jm1xp3z0zr2n9f7bsfl5zpvdshl8z";
      stripRoot = false;
    }}"
  ];

  services.home-assistant = {
    package = (pkgs.home-assistant.overrideAttrs (old: {
      doInstallCheck = false;
    })).override {
      extraPackages = pp: [ pp.croniter ];
    };
    config.pyscript = {
      allow_all_imports = true;
      hass_is_global = true;
    };
  };

  networking.firewall.interfaces.retiolum.allowedTCPPortRanges = [
    { from = 50321; to = 50341; } # for ipython interactive debugging
  ];
}
