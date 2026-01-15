{ callPackage }:

let
  mkHauntedPs1 = callPackage ../lib/mk-haunted-ps1.nix { };
in
mkHauntedPs1 {
  pname = "haunted-ps1-demo-disc-2021";
  zipName = "demodisc2021-win.zip";
  sha256 = "0392n5pgilpk0lgwr35w6jl6hq9h800y8lkpb729vjhw4c7ywsmm";
  exeName = "HauntedDemoDisc2021.exe";
  downloadUrl = "https://hauntedps1.itch.io/demodisc2021";
  downloadName = "Demo Disc 2021 [Windows]";
  desktopName = "Haunted PS1 Demo Disc 2021";
  description = "A collection of 25 PS1-style horror game demos from the Haunted PS1 community";
}
