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
      ${pkgs.sunshine}/bin/sunshine -1 ${pkgs.writeTextFile "sunshine.conf" ''
        channels = 5 # allow 5 clients to connect
        output_name = 1 # take external screen as default, maybe this breaks sometimes
      ''} "$@"
     '')
  ];
}
