{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let

  cfg = config.lass.usershadow;

  out = {
    options.lass.usershadow = api;
    config = lib.mkIf cfg.enable imp;
  };

  api = {
    enable = mkEnableOption "usershadow";
    pattern = mkOption {
      type = types.str;
      default = "/home/%/.shadow";
    };
    path = mkOption {
      type = types.str;
    };
  };

  imp = {
    environment.systemPackages = [ usershadow ];
    lass.usershadow.path = "${usershadow}";
    security.pam.services.sshd.text = ''
      auth required pam_exec.so expose_authtok /run/wrappers/bin/shadow_verify_pam ${cfg.pattern}
      auth required pam_permit.so
      account required pam_permit.so
      session required pam_permit.so
    '';

    security.pam.services.dovecot2.text = ''
      auth required pam_exec.so expose_authtok /run/wrappers/bin/shadow_verify_pam ${cfg.pattern}
      auth required pam_permit.so
      account required pam_permit.so
      session required pam_permit.so
    '';

    security.wrappers.shadow_verify_pam = {
      setuid = true;
      source = "${usershadow}/bin/verify_pam";
      owner = "root";
      group = "root";
    };
    security.wrappers.shadow_verify_arg = {
      setuid = true;
      source = "${usershadow}/bin/verify_arg";
      owner = "root";
      group = "root";
    };
  };

  usershadow =
    let
      deps = [
        "pwstore-fast"
        "bytestring"
      ];
    in
    pkgs.writeHaskellPackage "passwords" {
      ghc-options = [
        "-rtsopts"
        "-Wall"
      ];
      executables.verify_pam = {
        extra-depends = deps;
        text = ''
          import System.IO
          import Data.Char (chr)
          import System.Environment (getEnv, getArgs)
          import Crypto.PasswordStore (verifyPasswordWith, pbkdf2)
          import qualified Data.ByteString.Char8 as BS8
          import System.Exit (exitFailure, exitSuccess)

          main :: IO ()
          main = do
            user <- getEnv "PAM_USER"
            shadowFilePattern <- head <$> getArgs
            let shadowFile = lhs <> user <> tail rhs
                (lhs, rhs) = span (/= '%') shadowFilePattern
            hash <- readFile shadowFile
            password <- takeWhile (/= (chr 0)) <$> hGetLine stdin
            let res = verifyPasswordWith pbkdf2 (2^) (BS8.pack password) (BS8.pack hash)
            if res then exitSuccess else exitFailure
        '';
      };
      executables.verify_arg = {
        extra-depends = deps;
        text = ''
          import System.Environment (getArgs)
          import Crypto.PasswordStore (verifyPasswordWith, pbkdf2)
          import qualified Data.ByteString.Char8 as BS8
          import System.Exit (exitFailure, exitSuccess)

          main :: IO ()
          main = do
            argsList <- getArgs
            let shadowFilePattern = argsList !! 0
            let user = argsList !! 1
            let password = argsList !! 2
            let shadowFile = lhs <> user <> tail rhs
                (lhs, rhs) = span (/= '%') shadowFilePattern
            hash <- readFile shadowFile
            let res = verifyPasswordWith pbkdf2 (2^) (BS8.pack password) (BS8.pack hash)
            if res then do (putStr "yes") else exitFailure
        '';
      };
      executables.passwd = {
        extra-depends = deps;
        text = ''
          import System.Environment (getEnv)
          import Crypto.PasswordStore (makePasswordWith, pbkdf2)
          import qualified Data.ByteString.Char8 as BS8
          import System.IO (stdin, stdout, hSetEcho, hFlush, putStr, putStrLn)
          import Control.Exception (bracket_)

          main :: IO ()
          main = do
            home <- getEnv "HOME"
            mb_password <- bracket_ (hSetEcho stdin False) (hSetEcho stdin True) $ do
              putStr "Enter new UNIX password: "
              hFlush stdout
              password <- BS8.hGetLine stdin
              putStrLn ""
              putStr "Retype new UNIX password: "
              hFlush stdout
              password2 <- BS8.hGetLine stdin
              return $ if password == password2
                then Just password
                else Nothing
            case mb_password of
              Just password -> do
                hash <- makePasswordWith pbkdf2 password 10
                BS8.writeFile (home ++ "/.shadow") hash
                putStrLn "passwd: all authentication tokens updated successfully."
              Nothing -> putStrLn "Sorry, passwords do not match"
        '';
      };
    };

in
out
