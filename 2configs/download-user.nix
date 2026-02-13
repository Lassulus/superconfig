{ self, ... }:
{
  users.users.download = {
    isNormalUser = true;
    home = "/home/download";
    createHome = true;
    group = "users";
    useDefaultShell = true;
    openssh.authorizedKeys.keys = [
      self.keys.ssh.barnacle.public
      self.keys.ssh.yubi_pgp.public
      self.keys.ssh.yubi1.public
      self.keys.ssh.yubi2.public
      self.keys.ssh.solo2.public
      self.keys.ssh.xerxes.public
      self.keys.ssh.massulus.public
    ];
  };

  fileSystems."/home/download/yellow" = {
    device = "/var/download";
    fsType = "none";
    options = [
      "bind"
      "ro"
      "nofail"
      "x-systemd.automount"
    ];
  };
}
