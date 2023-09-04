{
  imports = [
    ./config.nix
  ];
  boot.isContainer = true;
  networking.useDHCP = false;
}
