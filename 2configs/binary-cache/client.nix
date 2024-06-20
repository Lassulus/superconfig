{
  nix.settings = {
    substituters = [
      "http://cache.neoprism.r"
      "https://cache.nixos.org/"
    ];
    trusted-public-keys = [
      "cache.prism-2:YwmCm3/s/D+SxrPKN/ETjlpw/219pNUbpnluatp6FKI="
      "hydra.nixos.org-1:CNHJZBh9K4tP3EKF6FkkgeVYsS3ohTl+oS0Qa8bezVs="
    ];
  };
}

