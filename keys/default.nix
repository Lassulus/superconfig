# Key structure exposed without nixpkgs dependency
# Uses only Nix builtins
let
  # Helper: split string by delimiter (returns only non-empty string parts)
  splitString = sep: str: builtins.filter builtins.isString (builtins.split sep str);

  # Helper: get last element of list
  last = list: builtins.elemAt list (builtins.length list - 1);

  # Helper: check if list is non-empty

  # Helper: unique elements in a list
  unique =
    list: builtins.foldl' (acc: elem: if builtins.elem elem acc then acc else acc ++ [ elem ]) [ ] list;

  # Helper to read age keys with different types
  readAgeKeys =
    baseDir:
    let
      dir = baseDir + "/age";
    in
    if builtins.pathExists dir then
      let
        allFiles = builtins.readDir dir;
        fileNames = builtins.attrNames allFiles;

        # Process a single file and return { name, public?, identity? }
        processFile =
          fileName:
          let
            fileType = allFiles.${fileName};
            parts = splitString "\\." fileName;
            baseName = builtins.head parts;
            extension = if builtins.length parts > 1 then last parts else "";
          in
          if fileType == "regular" then
            if extension == "age" then
              {
                name = baseName;
                public = builtins.readFile (dir + "/${fileName}");
                identity = null;
              }
            else if extension == "identity" then
              {
                name = baseName;
                public = null;
                identity = builtins.readFile (dir + "/${fileName}");
              }
            else
              null
          else
            null;

        # Process all files
        processed = builtins.filter (x: x != null) (map processFile fileNames);

        # Merge entries with same base name
        merged = builtins.foldl' (
          acc: entry:
          let
            existing =
              acc.${entry.name} or {
                public = null;
                identity = null;
              };
          in
          acc
          // {
            ${entry.name} = {
              public = if entry.public != null then entry.public else existing.public;
              identity = if entry.identity != null then entry.identity else existing.identity;
            };
          }
        ) { } processed;
      in
      merged
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
        fileNames = builtins.attrNames allFiles;

        # Extract base names (remove all suffixes)
        keyNames = unique (map (name: builtins.head (splitString "\\." name)) fileNames);
      in
      builtins.listToAttrs (
        map (
          keyName:
          let
            publicKeyFile = dir + "/${keyName}.pub";
            encryptedPrivateKeyFile = dir + "/${keyName}.age";
            hasPublicKey = builtins.pathExists publicKeyFile;
            hasEncryptedPrivateKey = builtins.pathExists encryptedPrivateKeyFile;
          in
          {
            name = keyName;
            value = {
              public = if hasPublicKey then builtins.readFile publicKeyFile else null;
              # Expose encrypted private keys (safe), but never unencrypted ones
              private = if hasEncryptedPrivateKey then encryptedPrivateKeyFile else null;
              encrypted = hasEncryptedPrivateKey;
            };
          }
        ) keyNames
      )
    else
      { };

  baseDir = ./.;
in
{
  # SSH keys (handle both public and private key files)
  ssh = readSshKeys baseDir;

  # PGP/GPG keys - define directly with metadata
  pgp = {
    yubi_pgp = {
      key = ./pgp/yubi_pgp.pgp;
      id = "DBCD757846069B392EA9401D6657BE8A8D1EE807";
    };
  };

  # Age keys (public keys only)
  age = readAgeKeys baseDir;
}
