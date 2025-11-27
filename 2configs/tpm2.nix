{ pkgs, lib, ... }:
let
  pinentry-askpass = pkgs.writeShellScriptBin "pinentry-askpass" ''
    result=$(cat <<EOF | ${pkgs.pinentry-gtk2}/bin/pinentry
SETDESC $1
SETPROMPT Passphrase:
GETPIN
EOF
    )
    echo "$result" | grep '^D ' | cut -d' ' -f2-
  '';
in
{
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    abrmd.enable = true;
  };
  environment.systemPackages = [
    pkgs.keyutils
    pinentry-askpass
  ];
  users.users.mainUser.extraGroups = [ "tss" ];

  systemd.user.services.ssh-tpm-agent = {
    description = "SSH TPM Agent";
    wantedBy = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.ssh-tpm-agent}/bin/ssh-tpm-agent -l %t/ssh-tpm-agent.sock --no-cache";
      Environment = [
        "SSH_ASKPASS=${lib.getExe pinentry-askpass}"
        "SSH_ASKPASS_REQUIRE=force"
      ];
      Restart = "on-failure";
    };
  };

  environment.sessionVariables = {
    SSH_AUTH_SOCK = "\${XDG_RUNTIME_DIR}/ssh-tpm-agent.sock";
  };
}
