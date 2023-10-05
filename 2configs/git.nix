{ self, config, lib, pkgs, ... }:

let
  git = self.inputs.stockholm.lib.git;
  out = {
    imports = [
      self.inputs.stockholm.nixosModules.git
    ];
    services.nginx.enable = true;
    krebs.git = {
      enable = true;
      cgit = {
        settings = {
          root-title = "public repositories at ${config.krebs.build.host.name}";
          root-desc = "keep calm and engage";
        };
      };
      repos = repos;
      rules = rules;
    };

    krebs.iptables.tables.filter.INPUT.rules = [
      { predicate = "-i retiolum -p tcp --dport 80"; target = "ACCEPT"; }
    ];

    system.activationScripts.spool-chmod = ''
      ${pkgs.coreutils}/bin/chmod +x /var/spool
    '';
  };

  cgit-clear-cache = pkgs.cgit-clear-cache.override {
    inherit (config.krebs.git.cgit.settings) cache-root;
  };

  repos =
    public-repos //
    lib.optionalAttrs config.krebs.build.host.secure restricted-repos;

  rules = lib.concatMap make-rules (lib.attrValues repos);

  public-repos = lib.mapAttrs make-public-repo {
    Reaktor = {
      cgit.desc = "Reaktor IRC bot";
      cgit.section = "software";
    };
    buildbot-classic = {
      cgit.desc = "fork of buildbot";
      cgit.section = "software";
    };
    cholerab = {
      cgit.desc = "krebs thesauron & enterprise-patterns";
      cgit.section = "documentation";
    };
    disko = {
      cgit.desc = "take a description of your disk layout and produce a format script";
      cgit.section = "software";
    };
    go = {
      cgit.desc = "url shortener";
      cgit.section = "software";
    };
    grib2json-bin = {
      cgit.desc = "build jar of grib2json";
      cgit.section = "deployment";
    };
    krebspage = {
      cgit.desc = "homepage of krebs";
      cgit.section = "configuration";
    };
    krops = {
      cgit.desc = "krebs deployment";
      cgit.section = "software";
    };
    news = {
      cgit.desc = "take a rss feed and a timeout and print it to stdout";
      cgit.section = "software";
    };
    newsbot-js = {
      cgit.desc = "print rss feeds to irc channels";
      cgit.section = "software";
    };
    nix-user-chroot = {
      cgit.desc = "Fork of nix-user-chroot by lethalman";
      cgit.section = "software";
    };
    nix-writers = {
      cgit.desc = "high level writers for nix";
      cgit.section = "software";
    };
    nixos-generators = {
      cgit.desc = "custom image builders";
      cgit.section = "software";
    };
    nixpkgs = {
      cgit.desc = "nixpkgs fork";
      cgit.section = "configuration";
    };
    populate = {
      cgit.section = "software";
    };
    reaktor2 = {
      cgit.desc = "irc bot";
      cgit.section = "software";
    };
    stockholm = {
      cgit.desc = "take all the computers hostage, they'll love you!";
      cgit.section = "configuration";
    };
    stockholm-issues = {
      cgit.desc = "stockholm issues";
      cgit.section = "issues";
    };
    the_playlist = {
      cgit.desc = "Good Music collection + tools";
      cgit.section  = "art";
    };
    workadventure-nix = {
      cgit.desc = "Nix packaging for workadventure";
      cgit.section = "deployment";
    };
    xmonad-stockholm = {
      cgit.desc = "krebs xmonad modules";
      cgit.section = "configuration";
    };
  };

  restricted-repos = lib.mapAttrs make-restricted-repo {
    brain = {
      collaborators = with config.krebs.users; [ tv makefu ];
      announce = true;
    };
  };

  make-public-repo = name: { cgit ? {}, collaborators ? [], ... }: {
    inherit cgit collaborators name;
    public = true;
    hooks = {
      post-receive = ''
        ${pkgs.git-hooks.irc-announce {
          # TODO make nick = config.krebs.build.host.name the default
          nick = config.krebs.build.host.name;
          channel = "#xxx";
          # TODO define refs in some kind of option per repo
          server = "irc.r";
          verbose = config.krebs.build.host.name == "orange";
        }}
        ${cgit-clear-cache}/bin/cgit-clear-cache
      '';
    };
  };

  make-public-repo-silent = name: { cgit ? {}, ... }: {
    inherit cgit name;
    public = true;
  };

  make-restricted-repo = name: { admins ? [], collaborators ? [], announce ? true, hooks ? {}, ... }: {
    inherit admins collaborators name;
    public = false;
    hooks = {
      post-receive = ''
        ${lib.optionalString announce (pkgs.git-hooks.irc-announce {
          # TODO make nick = config.krebs.build.host.name the default
          nick = config.krebs.build.host.name;
          channel = "#xxx";
          # TODO define refs in some kind of option per repo
          refs = [
            "refs/heads/master"
            "refs/heads/staging*"
          ];
          server = "irc.r";
          verbose = false;
        })}
        ${cgit-clear-cache}/bin/cgit-clear-cache
      '';
    } // hooks;
  };

  make-rules =
    with git // config.krebs.users;
    repo:
      lib.singleton {
        user = [ lass ];
        repo = [ repo ];
        perm = push "refs/*" [ non-fast-forward create delete merge ];
      } ++
      lib.optional (lib.length (repo.admins or []) > 0) {
        user = repo.admins;
        repo = [ repo ];
        perm = push "refs/*" [ non-fast-forward create delete merge ];
      } ++
      lib.optional (lib.length (repo.collaborators or []) > 0) {
        user = repo.collaborators;
        repo = [ repo ];
        perm = fetch;
      } ++
      lib.optional repo.public {
        user = lib.attrValues config.krebs.users;
        repo = [ repo ];
        perm = fetch;
      };

in out
