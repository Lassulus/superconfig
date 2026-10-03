# krebs.hosts and foreign krebs.users from the kartei flake input, instead
# of stockholm's nixosModules.kartei (which pins its own kartei submodule).
# Our own users are defined here from ../keys, not taken from kartei.
{
  config,
  lib,
  self,
  ...
}:
let
  inherit (self.inputs) kartei;

  # Host flag that is stockholm policy (krebs/3modules/kartei/overlay.nix),
  # not kartei data, still read by configs/consul.nix (retry_join).
  consulHosts = [
    "aergia"
    "blue"
    "coaxmetal"
    "daedalus"
    "green"
    "icarus"
    "ignavia"
    "littleT"
    "massulus"
    "neoprism"
    "orange"
    "radio"
    "shodan"
    "skynet"
    "styx"
    "ubik"
    "yellow"
  ];

  ownUsers = {
    lass = {
      mail = "lass@green.r";
      pgp.pubkeys.default = builtins.readFile ../keys/pgp/yubi_pgp.pgp;
      pubkey = lib.removeSuffix "\n" (builtins.readFile ../keys/ssh/yubi_pgp.pub);
    };
  };
in
{
  krebs.hosts = lib.mapAttrs (
    name: host:
    removeAttrs host [ "owner" ]
    // {
      # hosts may be owned by users without a kartei record; the krebs.users
      # type fills in all defaults from the name alone
      owner = config.krebs.users.${host.owner} or { name = host.owner; };
      consul = lib.elem name consulHosts;
    }
  ) kartei.hosts;

  # drop null fields so other modules (e.g. stockholm's users.nix for the
  # krebs user) can define them without conflicting definitions
  krebs.users =
    lib.mapAttrs (_: lib.filterAttrs (_: v: v != null)) (
      removeAttrs kartei.users (lib.attrNames ownUsers)
    )
    // ownUsers;
}
