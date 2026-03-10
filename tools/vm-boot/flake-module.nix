{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.vm-boot =
        (pkgs.writeShellApplication {
          name = "vm-boot";
          runtimeInputs = with pkgs; [
            qemu
            file
            util-linux
            nix
          ];
          text = builtins.readFile ./vm-boot.sh;
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
