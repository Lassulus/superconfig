{ ... }:
{
  # Full kubo (IPFS) node. Data lives under /var/lib/ipfs on the 4 TB root.
  # Uploads are copied into the blockstore (NO filestore/--nocopy on this host).
  services.kubo = {
    enable = true;
    dataDir = "/var/lib/ipfs";
    # No automatic GC: content is pinned on upload and only reclaimed by the
    # explicit `ipfs-gc` command (see ipfs-endpoint.nix).
    settings = {
      Addresses = {
        API = [ "/ip4/127.0.0.1/tcp/5001" ];
        Gateway = [ "/ip4/127.0.0.1/tcp/8089" ];
      };
      # Serve only local/pinned blocks -> the public gateway is not an open
      # proxy for arbitrary network CIDs.
      Gateway.NoFetch = true;
      # participate in the public swarm/DHT
      Datastore.StorageMax = "500GB";
    };
  };

  # incoming swarm connections (TCP + QUIC/UDP on 4001)
  networking.firewall.allowedTCPPorts = [ 4001 ];
  networking.firewall.allowedUDPPorts = [ 4001 ];
}
