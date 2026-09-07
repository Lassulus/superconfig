{
  pkgs,
  lib,
  self,
  ...
}:
let
  ssh-tpm-agent = self.packages.${pkgs.system}.ssh-tpm-agent;
  pinentry-rofi = self.packages.${pkgs.system}.pinentry-rofi;
in
{
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    abrmd.enable = true;
  };
  environment.systemPackages = [
    pkgs.keyutils
  ];
  users.users.mainUser.extraGroups = [ "tss" ];

  systemd.user.services.ssh-tpm-agent = {
    description = "SSH TPM Agent";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${ssh-tpm-agent}/bin/ssh-tpm-agent -l %t/ssh-tpm-agent.sock --no-cache";
      # systemd-launched programs don't source /etc/set-environment; publish
      # the socket to the user manager like gcr-ssh-agent does.
      ExecStartPost = "${pkgs.systemd}/bin/systemctl --user set-environment SSH_AUTH_SOCK=%t/ssh-tpm-agent.sock";
      Environment = [
        "SSH_ASKPASS=${lib.getExe pinentry-rofi}"
        "SSH_ASKPASS_REQUIRE=force"
      ];
      Restart = "on-failure";
    };
  };

  # gnome-keyring (desktops/lib/wayland.nix) pulls in gcr-ssh-agent, which
  # also sets SSH_AUTH_SOCK in the user manager and would shadow the TPM agent.
  services.gnome.gcr-ssh-agent.enable = false;

  environment.sessionVariables = {
    SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/ssh-tpm-agent.sock";
  };
}
