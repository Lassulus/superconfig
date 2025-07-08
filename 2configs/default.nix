{
  self,
  config,
  lib,
  pkgs,
  ...
}:
{
  # Clan core configuration
  clan.core.facts.secretStore = "password-store";
  clan.core.facts.secretUploadDirectory = lib.mkDefault "/etc/secrets";
  clan.core.vars.settings.secretStore = "password-store";
  clan.core.vars.password-store.passPackage = self.packages.${pkgs.system}.pass;
  clan.core.networking.targetHost = "root@${config.networking.hostName}";

  # Stockholm configuration
  krebs.secret.directory = config.clan.core.facts.secretUploadDirectory;

  # Nixpkgs overlays
  nixpkgs.overlays = [
    self.inputs.stockholm.overlays.default
    (import (self.inputs.stockholm.inputs.nix-writers + "/pkgs")) # TODO get rid of that overlay
  ];

  imports = [
    # Import 3modules
    ../3modules

    # Import stockholm krebs module
    self.inputs.stockholm.nixosModules.krebs

    # Import individual configurations
    ./security-workarounds.nix
    # ./binary-cache/client.nix
    ./gc.nix
    ./mc.nix
    ./zsh.nix
    ./htop.nix
    ./wiregrill.nix
    ./tor-ssh.nix
    ./networkd.nix
    ./pinned-registry.nix
    ./zerotier.nix
    ./nether.nix
    ./spora.nix
    ./nix.nix

    # Import stockholm modules
    self.inputs.stockholm.nixosModules.users
    self.inputs.stockholm.nixosModules.hosts
    self.inputs.stockholm.nixosModules.kartei
    self.inputs.stockholm.nixosModules.build
    self.inputs.stockholm.nixosModules.dns
    self.inputs.stockholm.nixosModules.exim
    self.inputs.stockholm.nixosModules.exim-retiolum
    self.inputs.stockholm.nixosModules.tinc
    self.inputs.stockholm.nixosModules.iptables
    self.inputs.stockholm.nixosModules.power-action
    self.inputs.stockholm.nixosModules.setuid
    self.inputs.stockholm.nixosModules.secret
    self.inputs.stockholm.nixosModules.sitemap
    self.inputs.stockholm.nixosModules.ssl
    self.inputs.stockholm.nixosModules.systemd
    self.inputs.stockholm.nixosModules.xresources
    self.inputs.stockholm.nixosModules.ssh
    self.inputs.stockholm.nixosModules.sync-containers3
    {
      # nix-index
      imports = [
        self.inputs.nix-index-database.nixosModules.nix-index
      ];
      programs.nix-index-database.comma.enable = true;
    }
    {
      # We need to mount these vars before the users phase, since that is the moment where the hashsed password are put into /etc/shadown
      users.extraUsers.mainUser.hashedPasswordFile =
        config.clan.core.vars.generators.password.files.passwordHash.path;
      users.extraUsers.root.hashedPasswordFile =
        config.clan.core.vars.generators.password.files.passwordHash.path;
      boot.initrd.systemd.emergencyAccess = true;
      clan.core.vars.generators.password = {
        prompts.password = {
          description = "Password for the main user";
          type = "hidden";
        };
        files.password.deploy = false;
        files.passwordHash.neededFor = "users";
        migrateFact = "password";
        runtimeInputs = with pkgs; [
          coreutils
          mkpasswd
        ];
        script = ''
          cp $prompts/password $out/password
          cat $out/password | mkpasswd -s -m sha-512 > $out/passwordHash
        '';
      };
    }
    {
      services.openssh.enable = true;
      services.openssh.hostKeys = [
        {
          path = config.clanCore.vars.generators.ssh.files."ssh.id_ed25519".path;
          type = "ed25519";
        }
      ];
      clan.core.vars.generators.ssh = {
        files."ssh.id_ed25519".secret = true;
        files."ssh.id_ed25519.pub".secret = false;
        migrateFact = "ssh";
        runtimeInputs = with pkgs; [
          coreutils
          openssh
        ];
        script = ''
          ssh-keygen -t ed25519 -N "" -f $out/ssh.id_ed25519
        '';
      };
    }
    {
      users.extraUsers = {
        root = {
          openssh.authorizedKeys.keys = [
            self.keys.ssh.barnacle.public
            self.keys.ssh.yubi_pgp.public
            self.keys.ssh.yubi1.public
            self.keys.ssh.yubi2.public
            self.keys.ssh.solo2.public
          ];
        };
        mainUser = {
          name = "lass";
          uid = 1337;
          home = "/home/lass";
          group = "users";
          createHome = true;
          useDefaultShell = true;
          isNormalUser = true;
          extraGroups = [
            "audio"
            "video"
            "fuse"
            "wheel"
            "tor"
            "dialout"
          ];
          openssh.authorizedKeys.keys = [
            self.keys.ssh.barnacle.public
            self.keys.ssh.yubi_pgp.public
            self.keys.ssh.yubi1.public
            self.keys.ssh.yubi2.public
            self.keys.ssh.solo2.public
          ];
        };
      };
    }
    (
      let
        ca-bundle = "/etc/ssl/certs/ca-bundle.crt";
      in
      {
        environment.variables = {
          CURL_CA_BUNDLE = ca-bundle;
          GIT_SSL_CAINFO = ca-bundle;
          SSL_CERT_FILE = ca-bundle;
        };
      }
    )
    {
      #for sshuttle
      environment.systemPackages = [
        pkgs.python3Packages.python
      ];
    }
  ];

  networking.hostName = config.krebs.build.host.name;

  krebs = {
    enable = true;
    build.user = config.krebs.users.lass;
    ssl.trustIntermediate = true;
  };

  users.mutableUsers = false;

  # multiple-definition-problem when defining environment.variables.EDITOR
  environment.extraInit = ''
    EDITOR=vim
  '';

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    self.packages.${pkgs.system}.nvim
    self.packages.${pkgs.system}.tmux

    git
    git-absorb
    git-preview
    gnumake
    jq
    nix-output-monitor
    comma

    #style
    rxvt-unicode-unwrapped.terminfo
    alacritty.terminfo

    #monitoring tools
    htop
    iotop

    #network
    iptables
    iftop
    tcpdump
    mosh
    eternal-terminal
    self.packages.${pkgs.system}.sshify

    #stuff for dl
    aria2

    #neat utils
    file
    hashPassword
    xkcdpass
    kpaste
    cyberlocker-tools
    pciutils
    pop
    q
    untilport
    (pkgs.writeDashBin "urgent" ''
      printf '\a'
    '')
    usbutils
    self.packages.${pkgs.system}.logify
    goify

    #unpack stuff
    libarchive

    (pkgs.writeDashBin "sshn" ''
      ${pkgs.openssh}/bin/ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "$@"
    '')
  ];

  environment.shellAliases = {
    ll = "ls -l";
    la = "ls -la";
    ls = "ls --color";
    ip = "ip -color=auto";
    grep = "grep --color=auto";
    nosleep = "systemd-inhibit --what=handle-lid-switch sleep infinity";
  };

  programs.bash = {
    completion.enable = true;
    interactiveShellInit = ''
      HISTCONTROL='erasedups:ignorespace'
      HISTSIZE=65536
      HISTFILESIZE=$HISTSIZE

      shopt -s checkhash
      shopt -s histappend histreedit histverify
      shopt -s no_empty_cmd_completion
      complete -d cd
      LS_COLORS=$LS_COLORS:'di=1;31:' ; export LS_COLORS
    '';
    promptInit = ''
      if test $UID = 0; then
        PS1='\[\033[1;31m\]\w\[\033[0m\] '
        PROMPT_COMMAND='echo -ne "\033]0;$$ $USER@$PWD\007"'
      elif test $UID = 1337; then
        PS1='\[\033[1;32m\]\w\[\033[0m\] '
        PROMPT_COMMAND='echo -ne "\033]0;$$ $PWD\007"'
      else
        PS1='\[\033[1;33m\]\u@\w\[\033[0m\] '
        PROMPT_COMMAND='echo -ne "\033]0;$$ $USER@$PWD\007"'
      fi
      if test -n "$SSH_CLIENT"; then
        PS1='\[\033[35m\]\h'" $PS1"
        PROMPT_COMMAND='echo -ne "\033]0;$$ $HOSTNAME $USER@$PWD\007"'
      fi
    '';
  };

  services.journald.extraConfig = ''
    SystemMaxUse=1G
    RuntimeMaxUse=128M
    Storage=persistent
  '';

  krebs.iptables = {
    enable = true;
    tables = {
      filter.INPUT.policy = "DROP";
      filter.FORWARD.policy = lib.mkDefault "DROP";
      filter.INPUT.rules = lib.mkMerge [
        (lib.mkBefore [
          {
            predicate = "-m conntrack --ctstate RELATED,ESTABLISHED";
            target = "ACCEPT";
          }
          {
            predicate = "-p icmp";
            target = "ACCEPT";
          }
          {
            predicate = "-p ipv6-icmp";
            target = "ACCEPT";
            v4 = false;
          }
          {
            predicate = "-i lo";
            target = "ACCEPT";
          }
          {
            predicate = "-p tcp --dport 22";
            target = "ACCEPT";
          }
        ])
        (lib.mkOrder 1000 [
          {
            predicate = "-p udp --dport 60000:61000";
            target = "ACCEPT";
          } # mosh
          {
            predicate = "-i retiolum -p udp -m udp --dport 53";
            target = "ACCEPT";
          }
          {
            predicate = "-i retiolum -p tcp --dport 19999";
            target = "ACCEPT";
          }
        ])
        (lib.mkAfter [
          {
            predicate = "-p tcp -i retiolum";
            target = "REJECT --reject-with tcp-reset";
          }
          {
            predicate = "-p udp -i retiolum";
            target = "REJECT --reject-with icmp-port-unreachable";
            v6 = false;
          }
          {
            predicate = "-i retiolum";
            target = "REJECT --reject-with icmp-proto-unreachable";
            v6 = false;
          }
        ])
      ];
    };
  };

  networking.extraHosts = ''
    10.42.0.1 styx.gg23
  '';

  # use 24:00 time format, the default got sneakily changed around 20.03
  i18n.defaultLocale = lib.mkDefault "C.UTF-8";
  time.timeZone = lib.mkDefault "Europe/Berlin";

  # disable doc usually
  documentation.nixos.enable = lib.mkDefault false;

  # use latest nix to hunt all the bugs
  nix.package = pkgs.nixVersions.latest;

}
