{ pkgs, ... }:
{
  services.pipewire.extraLv2Packages = [
    pkgs.lsp-plugins
    pkgs.bankstown-lv2
  ];

  services.pipewire.configPackages = [
    (pkgs.stdenv.mkDerivation {
      name = "gpd-pocket-4-pipewire";

      src = pkgs.fetchFromGitHub {
        owner = "Manawyrm";
        repo = "gpd-pocket-4-pipewire";
        rev = "4709659fcb4d4f77a852916e13655bb6174cc0e4";
        hash = "sha256-sC+/oIIKT9cyINmfdAXE0Qb18jeT6e8mtJi2cWHPYEQ=";
      };

      dontConfigure = true;
      dontBuild = true;

      postPatch = ''
        substituteInPlace pipewire.conf.d/sink-gpd-pocket-4.conf --replace-fail \
          '/usr/share/pipewire/pipewire.conf.d/' \
          "$out/share/pipewire/pipewire.conf.d/"
      '';

      installPhase = ''
        mkdir -p $out/share/pipewire
        cp -r pipewire.conf.d $out/share/pipewire
      '';
    })
  ];
}
