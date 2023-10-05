{ config, ... }:

{
  nix = {
    binaryCaches = [
      "http://cache.prism.r"
      "http://cache.neoprism.r"
      "https://cache.nixos.org/"
    ];
    binaryCachePublicKeys = [
      "cache.prism-1:+S+6Lo/n27XEtvdlQKuJIcb1yO5NUqUCE2lolmTgNJU="
      "cache.prism-2:YwmCm3/s/D+SxrPKN/ETjlpw/219pNUbpnluatp6FKI="
      "hydra.nixos.org-1:CNHJZBh9K4tP3EKF6FkkgeVYsS3ohTl+oS0Qa8bezVs="
    ];
  };
}

