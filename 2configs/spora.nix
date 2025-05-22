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
    keyFile = config.clan.core.vars.generators.mycelium.files.mycelium_key.path;
    extraArgs = [
      "--silent"
    ];
    peers = [
      "quic://10.42.0.1:9651"
      "tcp://10.42.0.1:9651"
    ];
  };
  clan.core.vars.generators.mycelium = {
    files."mycelium_key" = { };
    files."mycelium_ip".secret = false;
    files."mycelium_pubkey".secret = false;
    migrateFact = "mycelium";
    runtimeInputs = [
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
}
