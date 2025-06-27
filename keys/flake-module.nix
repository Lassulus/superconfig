{ lib, ... }:
let
  # Helper to read age keys with different types
  readAgeKeys =
    baseDir:
    let
      dir = baseDir + "/age";
    in
    if builtins.pathExists dir then
      let
        allFiles = builtins.readDir dir;
        # Group files by base name and type
        processFile =
          name: type:
          if type == "regular" then
            let
              parts = lib.splitString "." name;
              baseName = builtins.head parts;
              extension = if builtins.length parts > 1 then lib.last parts else "";
            in
            {
              name = baseName;
              value =
                if extension == "age" then
                  {
                    public = builtins.readFile (dir + "/${name}");
                    identity = null;
                  }
                else if extension == "identity" then
                  {
                    public = null;
                    identity = builtins.readFile (dir + "/${name}");
                  }
                else
                  null;
            }
          else
            null;

        # Process all files and merge by base name
        fileAttrs = lib.filterAttrs (_n: v: v != null) (lib.mapAttrs processFile allFiles);

        # Merge entries with same base name
        mergeEntries = lib.foldl' (
          acc: entry:
          let
            existing =
              acc.${entry.name} or {
                public = null;
                identity = null;
              };
            merged = {
              public = if entry.value.public != null then entry.value.public else existing.public;
              identity = if entry.value.identity != null then entry.value.identity else existing.identity;
            };
          in
          acc // { ${entry.name} = merged; }
        ) { } (lib.attrValues fileAttrs);
      in
      mergeEntries
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
      yubi_pgp = {
        key = ./pgp/yubi_pgp.pgp;
        id = "DBCD757846069B392EA9401D6657BE8A8D1EE807";
      };
    };

    # Age keys (public keys only)
    age = readAgeKeys ./.;
  };
}
