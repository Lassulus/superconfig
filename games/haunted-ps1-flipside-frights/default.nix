{ callPackage }:

let
  mkHauntedPs1 = callPackage ../lib/mk-haunted-ps1.nix { };
in
mkHauntedPs1 {
  pname = "haunted-ps1-flipside-frights";
  zipName = "demo-disc-flipside-frights-windows.zip";
  sha256 = "0g14mjj309mf5sk9bcgkwnk9xr9zyw3zcbrv12kpwl65wjcw38v5";
  exeName = "Demo Disc - Flipside Frights/DD04.exe";
  downloadUrl = "https://hauntedps1.itch.io/demo-disc-flipside-frights";
  downloadName = "demo-disc-flipside-frights-windows.zip (7.4 GB)";
  desktopName = "Haunted PS1 Demo Disc: Flipside Frights";
  description = "The latest Haunted PS1 demo disc featuring 24 horror game demos (2025)";
}
