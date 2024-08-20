{ self, ... }:
{
  imports = [
    self.inputs.stockholm.nixosModules.go
    # already done on radio container host
    # self.inputs.stockholm.nixosModules.htgen
  ];
  krebs.go = {
    enable = true;
  };
  services.nginx = {
    enable = true;
    virtualHosts."go.lassul.us" = {
      locations."/".extraConfig = ''
        proxy_set_header Host $host;
        proxy_pass http://localhost:1337;
      '';
      serverAliases = [
        "go.r"
      ];
    };
  };
}

