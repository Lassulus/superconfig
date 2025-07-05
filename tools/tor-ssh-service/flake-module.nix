{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.tor-ssh-service = pkgs.writeShellApplication {
        name = "tor-ssh-service";
        runtimeInputs = with pkgs; [
          tor
          coreutils
          gnugrep
          procps
          qrencode
        ];
        text = builtins.readFile ./tor-ssh-service.sh;
      };
    };
}
