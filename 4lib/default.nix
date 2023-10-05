{ lib, ... }:

with lib;

rec {

  getDefaultGateway = ip:
    concatStringsSep "." (take 3 (splitString "." ip) ++ ["1"]);

}
