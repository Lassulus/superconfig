{ ... }:
{
  imports = [
    <stockholm/lass/2configs/container-networking.nix>
    <stockholm/lass/2configs/syncthing.nix>
  ];
  krebs.sync-containers.containers.testi = {
    peers = [
      "coaxmetal"
    ];
    hostIp = "10.233.2.17";
    localIp = "10.233.2.18";
    format = "plain";
  };
}
