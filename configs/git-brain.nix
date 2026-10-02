{
  self,
  config,
  lib,
  pkgs,
  ...
}:
let
  git = self.inputs.stockholm.lib.git;
  repos = krebs-repos;
  rules = lib.concatMap krebs-rules (lib.attrValues krebs-repos);

  krebs-repos = lib.mapAttrs make-krebs-repo {
    brain = { };
  };

  make-krebs-repo =
    with git;
    name:
    {
      cgit ? { },
      ...
    }:
    {
      inherit cgit name;
      public = false;
      hooks = {
        post-receive = pkgs.git-hooks.irc-announce {
          nick = config.networking.hostName;
          verbose = true;
          channel = "#xxx";
          # TODO remove the hardcoded hostname
          server = "irc.r";
        };
      };
    };

  # TODO: get the list of all krebsministers
  krebsminister = with config.krebs.users; [
    makefu
    tv
    kmein
  ];
  krebs-rules = repo: set-owners repo [ config.krebs.users.lass ] ++ set-ro-access repo krebsminister;

  set-ro-access =
    with git;
    repo: user:
    lib.singleton {
      inherit user;
      repo = [ repo ];
      perm = fetch;
    };

  set-owners =
    with git;
    repo: user:
    lib.singleton {
      inherit user;
      repo = [ repo ];
      perm = push "refs/*" [
        non-fast-forward
        create
        delete
        merge
      ];
    };

in
{
  imports = [
    self.inputs.stockholm.nixosModules.git
  ];
  krebs.git = {
    enable = true;
    cgit = {
      enable = false;
    };
    inherit repos rules;
  };
}
