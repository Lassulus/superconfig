{ pkgs, lib, ... }:
let
  pinentry-askpass = pkgs.writeShellScriptBin "pinentry-askpass" ''
    # Use pinentry with auto-detection (graphical if available, curses fallback)
    result=$(cat <<EOF | ${pkgs.pinentry-all}/bin/pinentry
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
    pkgs.ssh-tpm-agent
    pkgs.keyutils
    pinentry-askpass
  ];
  environment.variables = {
    SSH_ASKPASS = lib.mkForce "/run/current-system/sw/bin/pinentry-askpass";
    SSH_ASKPASS_REQUIRE = "force";
  };
  users.users.mainUser.extraGroups = [ "tss" ];
}
