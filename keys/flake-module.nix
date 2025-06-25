{ self, lib, ... }:
let
  # Helper to read all files from a subdirectory
  readKeysFromDir = baseDir: subDir: 
    let
      dir = baseDir + "/${subDir}";
    in
    if builtins.pathExists dir then
      lib.mapAttrs (name: _: 
        let
          # Remove file extension to get key name
          keyName = lib.removeSuffix ".${subDir}" name;
        in
        builtins.readFile (dir + "/${name}")
      ) (builtins.readDir dir)
    else
      {};
  
  # Helper to read PGP keys with metadata
  readPgpKeysFromDir = baseDir:
    let
      dir = baseDir + "/pgp";
    in
    if builtins.pathExists dir then
      lib.mapAttrs (name: _: 
        let
          # Remove .pgp extension
          keyName = lib.removeSuffix ".pgp" name;
        in
        {
          key = dir + "/${name}";
          # For now, manually specify IDs - could be extracted from files later
          id = 
            if keyName == "yubi" then "DBCD757846069B392EA9401D6657BE8A8D1EE807"
            else null;
        }
      ) (builtins.readDir dir)
    else
      {};

in
{
  flake.keys = {
    # SSH keys (any format: rsa, ed25519, ecdsa)
    ssh = readKeysFromDir ./. "ssh";
    
    # PGP/GPG keys with metadata
    pgp = readPgpKeysFromDir ./.;
    
    # Age keys (including age-plugin-se keys from Secure Enclave)
    age = readKeysFromDir ./. "age";
    
    # Utility functions
    lib = {
      # Convert SSH Ed25519 public keys to age recipients
      # Note: Only works for Ed25519 keys, not ECDSA/RSA
      sshToAge = sshPubKey: 
        throw "sshToAge conversion requires runtime evaluation with ssh-to-age tool";
      
      # Check if a key is from Secure Enclave (age-plugin-se)
      isSecureEnclaveKey = ageKey:
        lib.hasPrefix "age1se1q" ageKey;
    };
  };
}