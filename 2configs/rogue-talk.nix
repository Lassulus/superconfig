{ self, config, pkgs, ... }:
{
  imports = [
    self.inputs.rogue-talk.nixosModules.default
  ];

  # Livekit keys generator
  clan.core.vars.generators."livekit" = {
    files.keyfile = { };
    files.api-key = { };
    files.api-secret = { };
    runtimeInputs = with pkgs; [
      livekit
      coreutils
      gnugrep
      gnused
    ];
    script = ''
      mkdir -p $out
      output=$(livekit-server generate-keys)
      api_key=$(echo "$output" | grep 'API Key:' | sed 's/.*API Key: //')
      api_secret=$(echo "$output" | grep 'API Secret:' | sed 's/.*API Secret: //')
      printf "%s: %s" "$api_key" "$api_secret" > $out/keyfile
      printf "%s" "$api_key" > $out/api-key
      printf "%s" "$api_secret" > $out/api-secret
    '';
  };

  # Rogue-Talk game server (includes livekit)
  services.rogue-talk-server = {
    enable = true;
    livekitKeyFile = config.clan.core.vars.generators."livekit".files."keyfile".path;
    livekitApiKeyFile = config.clan.core.vars.generators."livekit".files."api-key".path;
    livekitApiSecretFile = config.clan.core.vars.generators."livekit".files."api-secret".path;
  };
}
