# starkstrom is deliberately not in the shared kartei registry; its retiolum
# identity lives in retiolum/ (self.retiolum), which every superconfig machine
# injects into its tinc host set and /etc/hosts. Move that entry into
# kartei/lass if the rest of krebs should be able to reach it too.
{
  imports = [
    ../../configs
    ../../configs/retiolum.nix
    ../../configs/ssh-redirect.nix
    ../../configs/autoupdate.nix
    ../../configs/sigexec/executor.nix
    ./ipfs.nix
    ./ipfs-endpoint.nix
  ];

  # The fleet has no retiolum route here (see kartei note above), so the
  # sigexec dashboard on neoprism reaches this executor over public TLS
  # instead: nginx strips /sigexec/ so the executor verifies the same paths
  # the statements were signed over (/jobs etc).
  services.nginx.virtualHosts."starkstrom.lassul.us".locations."/sigexec/" = {
    proxyPass = "http://127.0.0.1:7601/";
    extraConfig = ''
      # Long-lived chunked job streams: unbuffered, generous timeouts (logs on
      # a pending job blocks until approval).
      proxy_buffering off;
      proxy_read_timeout 1d;
      proxy_send_timeout 1d;
    '';
  };

  system.stateVersion = "25.11";
}
