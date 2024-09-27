{ ... }:
{
  krebs.exim-retiolum = {
    enable = true;
    system-aliases = [
      {
        from = "root";
        to = "lass";
      }
    ];
  };
  krebs.iptables.tables.filter.INPUT.rules = [
    {
      predicate = "-i retiolum -p tcp --dport smtp";
      target = "ACCEPT";
    }
    {
      predicate = "-i zttzibeakb -p tcp --dport smtp";
      target = "ACCEPT";
    }
    {
      predicate = "-i nether -p tcp --dport smtp";
      target = "ACCEPT";
    }
  ];
}
