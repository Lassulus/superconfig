{
  services.syncthing.folders.decsync = {
    path = "/home/lass/decsync";
    devices = [ "mors" "blue" "green" "phone" "massulus" ];
  };

  krebs.acl."/home/lass/decsync"."u:syncthing:X".parents = true;
  krebs.acl."/home/lass/decsync"."u:syncthing:rwX" = {};
  krebs.acl."/home/lass/decsync"."u:lass:rwX" = {};
}
