{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      # Full-duplex voice conversations with Hermes: gpt-live-1 in the
      # browser, delegating real work to the Hermes API server.
      packages.hermes-voice =
        (pkgs.writeShellApplication {
          name = "hermes-voice";
          # A later --config on the command line overrides the packaged one.
          text = ''
            export HERMES_VOICE_STATIC=${./static}
            exec ${pkgs.python3}/bin/python3 ${./hermes_voice.py} --config ${./config.json} "$@"
          '';
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
