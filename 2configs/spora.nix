{ self, config, pkgs, ... }:
{
  imports = [
    self.inputs.spora.nixosModules.spora
  ];
  services.mycelium = {
    enable = true;
    keyFile = config.clanCore.facts.services.mycelium.secret.mycelium_key.path;
    peers = [
      # "quic://lassul.us:9651"
    ];
    package = self.packages.${pkgs.system}.mycelium;
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
