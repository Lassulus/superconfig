{ pkgs, ... }:
let
  # Cinny has no thread overview UI. Carry smokku's "threads-ui" drawer
  # (PR cinnyapp/cinny#2787, closed only due to Cinny's PR freeze during their
  # SDK rewrite) as a patch on top of the packaged release. Regenerate against
  # the new tag on each cinny bump; the patch touches ~16 files, conflicts have
  # historically been limited to RoomViewHeader.tsx.
  cinny-threads = pkgs.cinny.override {
    cinny-unwrapped = pkgs.cinny-unwrapped.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [ ./cinny-threads-ui.patch ];
    });
    conf = {
      defaultHomeserver = 0;
      homeserverList = [ "lassul.us" ];
      allowCustomHomeservers = true;
    };
  };
in
{
  services.nginx.virtualHosts."matrix.lassul.us".locations."/" = {
    root = cinny-threads;
    tryFiles = "$uri /index.html";
  };
}
