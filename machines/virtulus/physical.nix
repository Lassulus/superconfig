{
  imports = [
    ./config.nix
    ./disk.nix
  ];
  networking.useDHCP = true;
}
