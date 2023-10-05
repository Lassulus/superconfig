{ lib, stdenv, git, fetchzip, fetchFromGitHub, kernel }: let

  version = "9.1.7";

in stdenv.mkDerivation {
  pname = "drbd";
  version = "${kernel.version}-${version}";

  src = fetchzip {
    url = "https://pkg.linbit.com//downloads/drbd/9/drbd-9.1.7.tar.gz";
    sha256 = "sha256-JsbtOrqhZkG7tFEc6tDmj3RlxZggl0HOKfCI8lYtQok=";
  };
  # src = fetchFromGitHub {
  #   owner = "LINBIT";
  #   repo = "drbd";
  #   rev = "drbd-${version}";
  #   sha256 = "sha256-8HAt+k0yi6XsZZ9mkVCQkv2pn65o3Zsa0KwTSBJh0yY=";
  #   leaveDotGit = true;
  # };

  nativeBuildInputs = [ git ] ++ kernel.moduleBuildDependencies;

  # hardeningDisable = [ "pic" ];

  makeFlags = kernel.makeFlags ++ [
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  installPhase = ''
    install -D drbd/drbd.ko -t "$out/lib/modules/${kernel.modDirVersion}/updates/"
    install -D drbd/drbd_transport_tcp.ko -t "$out/lib/modules/${kernel.modDirVersion}/updates/"
  '';

  enableParallelBuilding = true;
}
