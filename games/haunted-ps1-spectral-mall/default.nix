{ callPackage }:

let
  mkHauntedPs1 = callPackage ../lib/mk-haunted-ps1.nix { };
in
mkHauntedPs1 {
  pname = "haunted-ps1-spectral-mall";
  zipName = "demodisc2022-win.zip";
  sha256 = "09c41dc0014myrlkpcichv34f4yvayqwns2cm5k9g1q880dhsmfz";
  exeName = "HPS1 Demo Disk Spectral Mall.exe";
  downloadUrl = "https://hauntedps1.itch.io/demo-disc-spectral-mall";
  downloadName = "The Haunted PS1 Demo Disc: Spectral Mall [Windows] (5.4 GB)";
  desktopName = "Haunted PS1 Demo Disc: Spectral Mall";
  description = "A PS1-style horror game demo disc set in a haunted mall";
}
