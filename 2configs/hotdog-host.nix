{ self, pkgs, ... }:
{
  imports = [
    (self.inputs.stockholm + "/krebs/2configs/hotdog-host.nix")
  ];
  clanCore.secrets.hotdog-container = {
    secrets."hotdog.sync.key" = { };
    facts."hotdog.sync.pub" = { };
    generator.path = with pkgs; [ coreutils openssh ];
    generator.script = ''
      ssh-keygen -t ed25519 -N "" -f "$secrets"/hotdog.sync.key
      mv "$secrets"/hotdog.sync.key "$facts"/hotdog.sync.pub
    '';
  };
}
