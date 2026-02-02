{
  config,
  pkgs,
  ...
}:
{
  # Generate Radicle identity keys using clan vars
  clan.core.vars.generators.radicle = {
    files."radicle.key" = { };
    files."radicle.pub".secret = false;
    runtimeInputs = [ pkgs.openssh ];
    script = ''
      ssh-keygen -t ed25519 -N "" -C "radicle" -f "$out/radicle.key"
      mv "$out/radicle.key.pub" "$out/radicle.pub"
    '';
  };

  services.radicle = {
    enable = true;
    privateKeyFile = config.clan.core.vars.generators.radicle.files."radicle.key".path;
    publicKey = config.clan.core.vars.generators.radicle.files."radicle.pub".path;

    node.openFirewall = true;

    settings = {
      publicExplorer = "https://app.radicle.xyz/nodes/$host/$rid$path";
      preferredSeeds = [
        "z6MkrLMMsiPWUcNPHcRajuMi9mDfYckSoJyPwwnknocNYPm7@seed.radicle.xyz:8776"
        "z6MkrLMMsiPWUcNPHcRajuMi9mDfYckSoJyPwwnknocNYPm7@irisradizskwweumpydlj4oammoshkxxjur3ztcmo7cou5emc6s5lfid.onion:8776"
        "z6Mkmqogy2qEM2ummccUthFEaaHvyYmYBYh3dbe9W4ebScxo@seed.radicle.garden:8776"
        "z6Mkmqogy2qEM2ummccUthFEaaHvyYmYBYh3dbe9W4ebScxo@rosarad5bxgdlgjnzzjygnsxrwxmoaj4vn7xinlstwglxvyt64jlnhyd.onion:8776"
      ];
      web.pinned.repositories = [ ];
      cli.hints = true;
      node = {
        alias = config.networking.hostName;
        listen = [ ];
        peers.type = "dynamic";
        connect = [ ];
        externalAddresses = [ ];
        network = "main";
        log = "INFO";
        relay = "auto";
        limits = {
          routingMaxSize = 1000;
          routingMaxAge = 604800;
          gossipMaxAge = 1209600;
          fetchConcurrency = 1;
          maxOpenFiles = 4096;
          rate = {
            inbound = {
              fillRate = 5.0;
              capacity = 1024;
            };
            outbound = {
              fillRate = 10.0;
              capacity = 2048;
            };
          };
          connection = {
            inbound = 128;
            outbound = 16;
          };
          fetchPackReceive = "500.0 MiB";
        };
        workers = 8;
        seedingPolicy = {
          default = "block";
        };
        proxy = "127.0.0.1:9050";
      };
    };
  };
}
