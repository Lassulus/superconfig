{ pkgs, ... }: {
  networking.firewall.allowedTCPPorts = [
    47984
    47989
    48010
  ];
  networking.firewall.allowedUDPPorts = [
    47998
    47999
    48000
  ];

  boot.kernelModules = [ "uinput" ];
  services.udev.extraRules = ''
    KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"
  '';

  environment.systemPackages = [
    (pkgs.writers.writeDashBin "sun" ''
      ${pkgs.sunshine}/bin/sunshine -0 -1 ${pkgs.writeText "sunshine.conf" ''
        channels = 5
        output_name = 1
      ''} "$@"
    '')
  ];
}
