{
  krebs.iptables = {
    enable = true;
    tables = {
      nat.PREROUTING.rules = [
        {
          predicate = "-i retiolum -p tcp -m tcp --dport 22";
          target = "ACCEPT";
        }
        {
          predicate = "-i wiregrill -p tcp -m tcp --dport 22";
          target = "ACCEPT";
        }
        {
          predicate = "-p tcp -m tcp --dport 22";
          target = "REDIRECT --to-ports 0";
        }
        {
          predicate = "-p tcp -m tcp --dport 45621";
          target = "REDIRECT --to-ports 22";
        }
      ];
      nat.OUTPUT.rules = [
        {
          predicate = "-o lo -p tcp -m tcp --dport 45621";
          target = "REDIRECT --to-ports 22";
        }
      ];
    };
  };
}
