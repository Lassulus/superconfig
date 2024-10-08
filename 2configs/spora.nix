{
  self,
  config,
  pkgs,
  ...
}:
{
  imports = [
    self.inputs.spora.nixosModules.spora
  ];
  services.mycelium = {
    enable = true;
    keyFile = config.clanCore.facts.services.mycelium.secret.mycelium_key.path;
    extraArgs = [
      "--silent"
    ];
    peers = [
      "quic://10.42.0.1:9651"
      "tcp://10.42.0.1:9651"
    ];
  };
  clanCore.facts.services.mycelium = {
    secret."mycelium_key" = { };
    public."mycelium_ip" = { };
    public."mycelium_pubkey" = { };
    generator = {
      path = [
        pkgs.mycelium
        pkgs.coreutils
        pkgs.jq
      ];
      script = ''
        timeout 5 mycelium --key-file "$secrets"/mycelium_key || :
        mycelium inspect --key-file "$secrets"/mycelium_key --json | jq -r .publicKey > "$facts"/mycelium_pubkey
        mycelium inspect --key-file "$secrets"/mycelium_key --json | jq -r .address > "$facts"/mycelium_ip
      '';
    };
  };
}
