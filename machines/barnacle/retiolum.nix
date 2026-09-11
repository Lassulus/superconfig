{
  self,
  config,
  pkgs,
  ...
}:

# Retiolum node, driven by kartei's nix-darwin module (tincr + host data
# straight out of the kartei host database). The NixOS machines run the same
# host database through nixpkgs' services.tinc instead, see
# 2configs/retiolum.nix.
let
  net = "retiolum";
  vars = config.clan.core.vars.generators.${net};
in
{
  imports = [ self.inputs.kartei.darwinModules.retiolum ];

  # nodename defaults to networking.hostName ("barnacle"); the addresses and
  # aliases come from lass/hosts/barnacle in kartei.

  networking.retiolum.ed25519PrivateKeyFile = vars.files."${net}.ed25519_key.priv".path;

  # Both merge with what kartei's module sets: hosts is attrsOf lines,
  # connectTo is listOf str.
  services.tincr.networks.${net} = {
    # Peers that only exist inside superconfig, on top of the kartei cards.
    hosts = self.retiolum.tincHosts;

    # kartei's module dials eve/eva/ni/prism -- krebs hubs that only learn
    # about barnacle when their own registry pins move. A laptop behind NAT
    # needs relays we control, so also dial our own public servers; same list
    # the NixOS nodes use in 2configs/retiolum.nix, plus starkstrom.
    connectTo = [
      "neoprism"
      "starkstrom"
    ];
  };

  # Same generator as 2configs/retiolum.nix, minus the RSA half: tincr is
  # SPTPS/Ed25519-only and kartei no longer wants an rsa.key.
  #
  # neededFor = "activation" because clan's /run/secrets installer is
  # Linux-only (tmpfs + move-mount), so on darwin the key is deployed as a
  # plain file below clan.core.vars.password-store.secretLocation.
  #
  # The public half is published in kartei as
  # lass/hosts/barnacle/retiolum/ed25519.key; keep this script stable or the
  # regenerated key will no longer match that card.
  clan.core.vars.generators.${net} = {
    files."${net}.ed25519_key.priv".neededFor = "activation";
    files."${net}.ed25519_key.pub".secret = false;
    runtimeInputs = [
      pkgs.coreutils
      self.packages.${pkgs.system}.tincr
    ];
    # generate-ed25519-keys wants a Name in tinc.conf and writes the pubkey as
    # a ready-made `Ed25519PublicKey = ...` line into hosts/$Name.
    script = ''
      mkdir -p "$out/hosts"
      echo 'Name = ${config.networking.hostName}' >"$out/tinc.conf"
      tinc --config "$out" generate-ed25519-keys
      mv "$out/ed25519_key.priv" "$out/${net}.ed25519_key.priv"
      mv "$out/hosts/${config.networking.hostName}" "$out/${net}.ed25519_key.pub"
      rm -r "$out/tinc.conf" "$out/hosts"
    '';
  };
}
