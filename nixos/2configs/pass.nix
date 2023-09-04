{ config, pkgs, ... }:

{
  users.users.mainUser.packages = with pkgs; [
    (pass.withExtensions (ext: [ ext.pass-otp ]))
    gnupg
    (pkgs.writers.writeDashBin "unlock" ''
      set -efu
      HOST=$1

      pw=$(pass show "admin/$HOST/luks")
      torify sshn root@$(pass "hosts/$HOST/initrd/hostname") "echo $pw > /crypt-ramfs/passphrase"
    '')
  ];

  programs.gnupg.agent.enable = true;
  systemd.tmpfiles.rules = [
    "L+ /home/lass/.password-store - - - - sync/pwstore"
  ];

}
