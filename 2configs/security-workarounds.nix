{
  imports = [ 
    { # CVE-2024-3094
      # https://www.openwall.com/lists/oss-security/2024/03/29/4
      # https://github.com/NixOS/nixpkgs/pull/300028
      # NixOS is not affected
    }
    { # CVE-2024-6387
      # https://github.com/NixOS/nixpkgs/pull/323753#issuecomment-2199762128
      services.openssh.settings.LoginGraceTime = 0;
    }
  ];
}
