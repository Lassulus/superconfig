{ callPackage }:

let
  mkHauntedPs1 = callPackage ../lib/mk-haunted-ps1.nix { };
in
mkHauntedPs1 {
  pname = "haunted-ps1-demo-disc-2020";
  zipName = "demodisc2020-win.zip";
  sha256 = "14d18l0kcbjim2rczg9lcmvgs46n6bs7pisfg33qnarwiv40v5f3";
  exeName = "Haunted PS1 Demo Disc/Haunted PS1 Demo Disc.exe";
  downloadUrl = "https://hauntedps1.itch.io/demodisc2020";
  downloadName = "demodisc2020-win.zip (2.8 GB)";
  desktopName = "Haunted PS1 Demo Disc 2020";
  description = "A collection of PS1-style horror game demos from the Haunted PS1 community (2020 edition)";
}
