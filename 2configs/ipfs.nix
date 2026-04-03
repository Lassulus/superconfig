{ ... }:
let
  neoprismPeerID = "12D3KooWDccB4dVFt6uyfD5Yc3brwj4JLSztPeJpY3yg965iB5uT";
  neoprismAddrs = [
    "/ip6/42:0:ce16::99/tcp/4001/p2p/${neoprismPeerID}"
    "/ip4/95.217.192.59/tcp/4001/p2p/${neoprismPeerID}"
  ];
in
{
  services.kubo = {
    enable = true;
    settings = {
      Addresses = {
        API = [
          "/ip4/127.0.0.1/tcp/5001"
          "/ip6/::1/tcp/5001"
        ];
        Gateway = [
          "/ip4/127.0.0.1/tcp/8089"
          "/ip6/::1/tcp/8089"
        ];
        # don't listen for incoming swarm connections
        Swarm = [ ];
      };

      # only connect to neoprism, no public DHT
      Bootstrap = neoprismAddrs;
      Peering.Peers = [
        {
          ID = neoprismPeerID;
          Addrs = [
            "/ip6/42:0:ce16::99/tcp/4001"
            "/ip4/95.217.192.59/tcp/4001"
          ];
        }
      ];

      # minimal connections
      Swarm.ConnMgr = {
        LowWater = 1;
        HighWater = 5;
        GracePeriod = "10s";
      };
      Swarm.Transports.Network.TCP = true;
      Swarm.Transports.Network.QUIC = false;
      Swarm.RelayClient.Enabled = false;
      Swarm.RelayService.Enabled = false;
      Swarm.ResourceMgr = {
        Enabled = true;
        MaxMemory = "128MB";
      };

      # don't route for others, don't announce to DHT
      Routing.Type = "none";
      AutoTLS.AutoWSS = false;

      # don't provide/announce content to the network
      Provide.Enabled = false;

      Datastore.StorageMax = "10GB";
    };
  };

  # no firewall ports needed — we don't accept incoming connections
}
