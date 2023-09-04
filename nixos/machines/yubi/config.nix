{ config, lib, pkgs, ... }:

# cryptsetup luksOpen /dev/xxx mmc
# mkdir /mnt
# mount /dev/mapper/mmc /mnt
# rm -rf $GNUPGHOME
# cp -rv /mnt/gnupghome $GNUPGHOME
#
### change yubikey pin
# gpg --card-edit
# > admin
# > passwd
# > 1
# > > 123456
# > > $newpin
# > 3
# > > 12345678
# > > $newpuk
#
### transfer keys
# gpg --edit-key $keyid
#
# for x in 1 2 3
# > key $x
# > expire
# > 2y
# > keytocard
# > > $newpuk
# > key $x (to unselect)

{
  services.pcscd.enable = true;
  services.udev.packages = [ yubikey-personalization ];

  environment.systemPackages = [ gnupg pinentry-curses pinentry-qt paperkey wget ];

  programs = {
    ssh.startAgent = false;
    gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };
  };
  boot.tmpOnTmpfs = true;
}
