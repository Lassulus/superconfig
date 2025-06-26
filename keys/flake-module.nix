{ lib, ... }:
let
  # Helper to read all files from a subdirectory
  readKeysFromDir =
    baseDir: subDir:
    let
      dir = baseDir + "/${subDir}";
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

in
{
  flake.keys = {
    # SSH keys (any format: rsa, ed25519, ecdsa)
    ssh = readKeysFromDir ./. "ssh";

    # PGP/GPG keys - define directly with metadata
    pgp = {
      yubi = {
        key = ./pgp/yubi.pgp;
        id = "DBCD757846069B392EA9401D6657BE8A8D1EE807";
      };
    };

    # Age keys
    age = readKeysFromDir ./. "age";
  };
}
