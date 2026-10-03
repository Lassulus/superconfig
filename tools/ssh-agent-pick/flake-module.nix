{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.ssh-agent-pick =
        (pkgs.writeShellApplication {
          name = "ssh-agent-pick";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.findutils
            pkgs.fzf
            pkgs.gawk
            pkgs.openssh
          ];
          text = builtins.readFile ./ssh-agent-pick.sh;
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
