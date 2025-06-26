{ lib, ... }:
let
  # Helper to read age keys (public keys only)
  readAgeKeys =
    baseDir:
    let
      dir = baseDir + "/age";
    in
    if builtins.pathExists dir then
      lib.mapAttrs' (
        name: _:
        let
          # Remove everything after the first dot
          keyName = builtins.head (lib.splitString "." name);
        in
        lib.nameValuePair keyName (builtins.readFile (dir + "/${name}"))
      ) (builtins.readDir dir)
    else
      { };

  # Helper to read SSH keys (handle key pairs and encrypted private keys)
  readSshKeys =
    baseDir:
    let
      dir = baseDir + "/ssh";
    in
    if builtins.pathExists dir then
      let
        allFiles = builtins.readDir dir;
        # Group files by their base name (remove all suffixes)
        keyNames = lib.unique (
          map (name: builtins.head (lib.splitString "." name)) (builtins.attrNames allFiles)
        );
      in
      lib.listToAttrs (
        map (
          keyName:
          let
            publicKeyFile = dir + "/${keyName}.pub";
            encryptedPrivateKeyFile = dir + "/${keyName}.age";
            hasPublicKey = builtins.pathExists publicKeyFile;
            hasEncryptedPrivateKey = builtins.pathExists encryptedPrivateKeyFile;
          in
          lib.nameValuePair keyName {
            public = if hasPublicKey then builtins.readFile publicKeyFile else null;
            # Expose encrypted private keys (safe), but never unencrypted ones
            private = if hasEncryptedPrivateKey then encryptedPrivateKeyFile else null;
            encrypted = hasEncryptedPrivateKey;
          }
        ) keyNames
      )
    else
      { };

in
{
  flake.keys = {
    # SSH keys (handle both public and private key files)
    ssh = readSshKeys ./.;

    # PGP/GPG keys - define directly with metadata
    pgp = {
      yubi = {
        key = ./pgp/yubi.pgp;
        id = "DBCD757846069B392EA9401D6657BE8A8D1EE807";
      };
    };

    # Age keys (public keys only)
    age = readAgeKeys ./.;
  };
}
