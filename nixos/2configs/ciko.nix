{ config, pkgs, ... }:
{
  users.users.ciko = {
    uid = genid_uint31 "ciko";
    description = "acc for ciko";
    home = "/home/ciko";
    useDefaultShell = true;
    createHome = true;
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDTUWm/fISw/gbuHvf3kwxGEuk1aY5HrNNvr8QXCQv0khDdaYmZSELbtFQtE04WGTWmackNcLpld5mETVyCM0BjOgqMJYQNhtywxfYcodEY5xxHCuGgA3S1t94MZub+DRodXCfB0yUV85Wbb0sltkMTJufMwYmLEGxSLRukxAOcNsXdjlyro96csmYrIiV6R7+REnz8OcR7sKlI4tvKA1mbvWmjbDBd1MZ8Jc0Lwf+b0H/rH69wEQIcB5HRHHJIChoAk0t2azSjXagk1+4AebONZTCKvTHxs/D2wUBIzoxyjmh5S0aso/cKw8qpKcl/A2mZiIvW3KMlJAM5U+RQKMrr"
    ];
    isNormalUser = true;
  };

  system.activationScripts.user-shadow = ''
    ${pkgs.coreutils}/bin/chmod +x /home/ciko
  '';
}

