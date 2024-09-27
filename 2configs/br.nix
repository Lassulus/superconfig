{ pkgs, modulesPath, ... }:
{

  imports = [
    (modulesPath + "/services/hardware/sane_extra_backends/brscan4.nix")
  ];

  hardware.sane = {
    enable = true;
    brscan4 = {
      enable = true;
      netDevices = {
        bra = {
          model = "MFCL2700DN";
          ip = "10.42.0.4";
        };
      };
    };
  };

  services.saned.enable = true;

  # usage: scanimage -d "$(find-scanner bra)" --batch --format=tiff --resolution 150  -x 211 -y 298
  environment.systemPackages = [
    (pkgs.writeDashBin "find-scanner" ''
      set -efu
      name=$1
      ${pkgs.sane-backends}/bin/scanimage -f '%m %d
      ' \
      | ${pkgs.gawk}/bin/awk -v dev="*$name" '$1 == dev { print $2; exit }' \
      | ${pkgs.gnugrep}/bin/grep .
    '')
  ];

  services.printing = {
    enable = true;
    drivers = [
      pkgs.mfcl2700dncupswrapper
    ];
  };

  users.users.mainUser.extraGroups = [
    "scanner"
    "lp"
  ];

}
