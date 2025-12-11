{
  self,
  config,
  pkgs,
  ...
}:
{
  imports = [
    self.inputs.stockholm.nixosModules.htgen
  ];
  krebs.sync-containers3.containers.radio = {
    sshKey = "${config.krebs.secret.directory}/radio.sync.key";
    startCommand = ''
      export PATH=$PATH:${pkgs.git}/bin
      until ${pkgs.dig.host}/bin/host github.com; do sleep 1; done
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild --refresh --flake github:lassulus/superconfig#radio switch --no-write-lock-file
    '';
  };
  containers.radio = {
    bindMounts."/var/music" = {
      hostPath = "/var/music";
      isReadOnly = false;
    };
  };
  clan.core.vars.generators.radio-container = {
    files."radio.sync.key" = { };
    prompts.key.description = ''
      copy or reference the secret key from the container into here, so we can actually start/sync the container
    '';
    script = ''
      cat "$prompts"/key > "$out"/radio.sync.key
    '';
  };
}
