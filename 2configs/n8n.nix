{
  ...
}:
{
  services.n8n = {
    enable = true;
    openFirewall = true;
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
