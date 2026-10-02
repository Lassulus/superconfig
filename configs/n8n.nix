{
  ...
}:
{
  services.n8n = {
    enable = true;
    openFirewall = true;
    environment.N8N_SECURE_COOKIE = "false";
  };

  krebs.iptables.tables.filter.INPUT.rules = [
    {
      predicate = "-i retiolum -p tcp --dport 5678";
      target = "ACCEPT";
    }
    {
      predicate = "-i wiregrill -p tcp --dport 5678";
      target = "ACCEPT";
    }
  ];
}
