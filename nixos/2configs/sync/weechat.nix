{
  services.syncthing.folders."/home/lass/.weechat".devices = [ "green" "mors" ];
  krebs.acl."/home/lass/.weechat"."u:syncthing:X".parents = true;
  krebs.acl."/home/lass/.weechat"."u:syncthing:rwX" = {};
  krebs.acl."/home/lass/.weechat"."u:lass:rwX" = {};
}
