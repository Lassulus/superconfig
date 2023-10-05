{ self, ... }:
{
  imports = [ self.inputs.stockholm.nixosModules.acl ];
  services.syncthing.settings.folders."/home/lass/sync" = {
    devices = [
      "mors"
      "xerxes"
      "green"
      "blue"
      "coaxmetal"
      "aergia"
    ];
    versioning = {
      type = "trashcan";
      params = {
        cleanoutDays = "30";
      };
    };
  };
  krebs.acl."/home/lass/sync"."u:syncthing:X".parents = true;
  krebs.acl."/home/lass/sync"."u:syncthing:rwX" = {};
  krebs.acl."/home/lass/sync"."u:lass:rwX" = {};
}
