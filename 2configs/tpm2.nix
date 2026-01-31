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
      Environment = [
        "SSH_ASKPASS=${lib.getExe pinentry-rofi}"
        "SSH_ASKPASS_REQUIRE=force"
      ];
      Restart = "on-failure";
    };
  };

  environment.sessionVariables = {
    SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/ssh-tpm-agent.sock";
  };
}
