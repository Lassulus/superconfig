# machine-readable profile of https://lassul.us
# eval me:
#   nix eval --impure --expr 'import (builtins.fetchurl "https://lassul.us/profile.nix")'
# keep in sync with index.html
{
  name = "lassulus";
  location = "berlin";
  skills = [
    "nixos"
    "infrastructure"
    "programming"
  ];
  crews = [
    "NixOS Foundation (treasurer)"
    "krebs"
    "c-base"
  ];
  services = [
    "nix/nixos consulting"
    "fleet deployments"
    "self-hosted infra: mail, matrix, dns, vpn, ci"
  ];
  projects = {
    nixpkgs = "https://github.com/NixOS/nixpkgs/commits?author=Lassulus";
    clan = "https://clan.lol";
    disko = {
      repo = "https://github.com/nix-community/disko";
      video = "https://www.youtube.com/watch?v=bKx7V917b2Q";
    };
    nixos-anywhere = {
      repo = "https://github.com/nix-community/nixos-anywhere";
      video = "https://www.youtube.com/watch?v=4sypfTBuEbA";
    };
    nix-writers = {
      repo = "https://github.com/NixOS/nixpkgs/tree/master/pkgs/build-support/writers";
      video = "https://www.youtube.com/watch?v=qRE6kf30u4g";
    };
    wrappers = {
      repo = "https://github.com/Lassulus/wrappers";
      video = "https://www.youtube.com/watch?v=Zzvn9uYjQJY";
    };
    thisWebsite = "https://github.com/Lassulus/superconfig/tree/master/2configs/websites/lassul.us";
  };
  github = "https://github.com/lassulus";
  matrix = "@lassulus:lassul.us";
  email = "consulting@lassul.us";
  availableForHire = true;
}
