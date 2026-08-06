{ config, ... }:

let
  self = config.krebs.build.host.nets.retiolum;
  neoprism = config.krebs.hosts.neoprism.nets.retiolum;
  port = 8118;
in
{
  # Forward proxy that lets neoprism push YouTube traffic out over this box's
  # residential line. YouTube throttles and captchas Hetzner ranges hard, so
  # invidious (2configs/services/invidious.nix) tunnels every innertube call
  # and video stream through here instead of using neoprism's own address.
  services.tinyproxy = {
    enable = true;
    settings = {
      Listen = self.ip4.addr;
      Port = port;
      # never an open proxy: only neoprism may use this exit
      Allow = neoprism.ip4.addr;
      # everything invidious does is https, so CONNECT needs nothing else
      ConnectPort = 443;
      # video streams are long-lived; the default 600s is plenty per request
      Timeout = 600;
      MaxClients = 128;
      DisableViaHeader = true;
      # one line per proxied request would be pure noise at video chunk rates
      LogLevel = "Warning";
    };
  };

  # Listen binds a retiolum address, which only exists once tinc is up. Retry
  # forever instead of hitting the default start limit and staying dead.
  systemd.services.tinyproxy = {
    after = [ "tinc.retiolum.service" ];
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig.RestartSec = "5s";
  };

  krebs.iptables.tables.filter.INPUT.rules = [
    {
      predicate = "-i retiolum -p tcp --dport ${toString port}";
      target = "ACCEPT";
    }
  ];
}
