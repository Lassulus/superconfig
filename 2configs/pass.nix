{ pkgs, self, ... }:

{
  users.users.mainUser.packages = with pkgs; [
    self.packages.${pkgs.system}.passmenu
    self.packages.${pkgs.system}.pass
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
