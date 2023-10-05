{ self, ... }:
{
  imports = [
    self.inputs.stockholm.nixosModules.go
    self.inputs.stockholm.nixosModules.htgen
  ];
  krebs.go = {
    enable = true;
  };
  services.nginx = {
    enable = true;
    virtualHosts.go = {
      locations."/".extraConfig = ''
        proxy_set_header Host go.lassul.us;
        proxy_pass http://localhost:1337;
      '';
      serverAliases = [
        "go.lassul.us"
      ];
    };
  };
}

