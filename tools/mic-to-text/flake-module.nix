{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.mic-to-text = pkgs.writeShellApplication {
        name = "mic-to-text";
        runtimeInputs = [
          pkgs.sox
          pkgs.whisper-cpp
          pkgs.curl
        ];
        text = builtins.readFile ./mic-to-text.sh;
      };
    };
}
