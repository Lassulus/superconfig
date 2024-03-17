{ self, config, pkgs, ... }:
{
  imports = [
    self.inputs.spora.nixosModules.spora
  ];
  services.mycelium.keyFile = config.clanCore.secrets.mycelium.secrets.mycelium_key.path;
  clanCore.secrets.mycelium = {
    secrets."mycelium_key" = { };
    facts."mycelium_ip" = { };
    facts."mycelium_pubkey" = { };
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
