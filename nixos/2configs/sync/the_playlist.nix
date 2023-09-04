{
  services.syncthing.folders.the_playlist = {
    path = "/home/lass/tmp/the_playlist";
    devices = [ "mors" "phone" "prism" "omo" "radio" ];
  };
  krebs.acl."/home/lass/tmp/the_playlist"."u:syncthing:X".parents = true;
  krebs.acl."/home/lass/tmp/the_playlist"."u:syncthing:rwX" = {};
  krebs.acl."/home/lass/tmp/the_playlist"."u:lass:rwX" = {};
}
