{
  self,
  config,
  lib,
  pkgs,
  ...
}:
let

  to = lib.concatStringsSep "," [
    "lass@green.r"
  ];

  mails = [
    "postmaster@lassul.us"
    "lassulus@lassul.us"
    "test@lassul.us"
    "outlook@lassul.us"
    "steuer@aidsballs.de"
    "lass@aidsballs.de"
    "finanzamt@lassul.us"
    "netzclub@lassul.us"
    "nebenan@lassul.us"
    "feed@lassul.us"
    "art@lassul.us"
    "irgendwas@lassul.us"
    "polo@lassul.us"
    "shack@lassul.us"
    "nix@lassul.us"
    "c-base@lassul.us"
    "paypal@lassul.us"
    "patreon@lassul.us"
    "steam@lassul.us"
    "securityfocus@lassul.us"
    "radio@lassul.us"
    "btce@lassul.us"
    "raf@lassul.us"
    "apple@lassul.us"
    "coinbase@lassul.us"
    "tomtop@lassul.us"
    "aliexpress@lassul.us"
    "business@lassul.us"
    "payeer@lassul.us"
    "github@lassul.us"
    "bitwala@lassul.us"
    "bitstamp@lassul.us"
    "bitcoin.de@lassul.us"
    "ableton@lassul.us"
    "dhl@lassul.us"
    "sipgate@lassul.us"
    "coinexchange@lassul.us"
    "verwaltung@lassul.us"
    "gearbest@lassul.us"
    "binance@lassul.us"
    "bitfinex@lassul.us"
    "alternate@lassul.us"
    "redacted@lassul.us"
    "mytaxi@lassul.us"
    "pizza@lassul.us"
    "robinhood@lassul.us"
    "drivenow@lassul.us"
    "aws@lassul.us"
    "reddit@lassul.us"
    "banggood@lassul.us"
    "immoscout@lassul.us"
    "gmail@lassul.us"
    "amazon@lassul.us"
    "humblebundle@lassul.us"
    "meetup@lassul.us"
    "gebfrei@lassul.us"
    "github@lassul.us"
    "ovh@lassul.us"
    "hetzner@lassul.us"
    "allygator@lassul.us"
    "immoscout@lassul.us"
    "elitedangerous@lassul.us"
    "boardgamegeek@lassul.us"
    "qwertee@lassul.us"
    "zazzle@lassul.us"
    "hackbeach@lassul.us"
    "transferwise@lassul.us"
    "cis@lassul.us"
    "afra@lassul.us"
    "ksp@lassul.us"
    "ccc@lassul.us"
    "neocron@lassul.us"
    "osmocom@lassul.us"
    "lesswrong@lassul.us"
    "nordvpn@lassul.us"
    "csv-direct@lassul.us"
    "nintendo@lassul.us"
    "overleaf@lassul.us"
    "box@lassul.us"
    "paloalto@lassul.us"
    "subtitles@lassul.us"
    "lobsters@lassul.us"
    "fysitech@lassul.us"
    "threema@lassul.us"
    "ubisoft@lassul.us"
    "kottezeller@lassul.us"
    "pie@lassul.us"
    "vebit@lassul.us"
    "vcvrack@lassul.us"
    "epic@lassul.us"
    "microsoft@lassul.us"
    "stickers@lassul.us"
    "nextbike@lassul.us"
    "mytello@lassul.us"
    "camp@lassul.us"
    "urlwatch@lassul.us"
    "lidl@lassul.us"
    "geizhals@lassul.us"
    "auschein@lassul.us"
    "tleech@lassul.us"
    "durstexpress@lassul.us"
    "acme@lassul.us"
    "antstore@lassul.us"
    "openweather@lassul.us"
    "lobsters@lassul.us"
    "rewe@lassul.us"
    "spotify@lassul.us"
    "mojang@lassul.us"
    # "telekom@lassul.us"
    "doctolib@lassul.us"
    "dragonbox@lassul.us"
    "scalable@lassul.us"
    "remarkable@lassul.us"
    "lenovo@lassul.us"
    "lapstars@lassul.us"
    "simplywall@lassul.us"
    "vytal@lassul.us"
    "haftpflicht@lassul.us"
    "dji@lassul.us"
    "sparkasse@lassul.us"
    "ikea@lassul.us"
    "blizzard@lassul.us"
    "azure@lassul.us"
    "engadin@lassul.us"
    "jameda@lassul.us"
    "flaschenpost@lassul.us"
    "irc@lassul.us"
    "dlive*@lassul.us"
    "bunq@lassul.us"
    "telegram@lassul.us"
    "ryanair@lassul.us"
    "phone@lassul.us"
    "bitmex@lassul.us"
    "matrix@lassul.us"
    "itch@lassul.us"
    "revolut@lassul.us"
    "coronatest@lassul.us"
    "dcso@lassul.us"
    "easyjet@lassul.us"
    "flipper@lassul.us"
    "figma@lassul.us"
    "psiram@lassul.us"
    "wahl@lassul.us"
    "instagram@lassul.us"
    "poinbit@lassul.us"
    "vvs@lassul.us"
    "juicy@lassul.us"
    "auth0@lassul.us"
    "opodo@lassul.us"
    "mytrip@lassul.us"
    "kraken@lassul.us"
    "swisspass@lassul.us"
    "heise@lassul.us"
    "dplf@lassul.us"
    "rc3@lassul.us"
    "booking@lassul.us"
    "mozilla@lassul.us"
    "bolt@lassul.us"
    "wolt@lassul.us"
    "independesk@lassul.us"
    "oracle@lassul.us"
    "dev@lassul.us"
    "nebula@lassul.us"
    "golem@lassul.us"
    "planet@lassul.us"
    "zerotier@lassul.us"
    "coqui@lassul.us"
    "numtide@lassul.us"
    "linkedin@lassul.us"
    "kaggle@lassul.us"
    "lastfm@lassul.us"
    "obi@lassul.us"
    "aok@lassul.us"
    "sevdesk@lassul.us"
    "penta@lassul.us"
    "solarisbank@lassul.us"
    "tinder@lassul.us"
    "vodafone@lassul.us"
    "42keebs@lassul.us"
    "pcb@lassul.us"
    "splitkb@lassul.us"
    "brackethq@lassul.us"
    "fosdem@lassul.us"
    "nreal@lassul.us"
    "packaging@lassul.us"
    "ebay@lassul.us"
    "fusion@lassul.us"
    "uber@lassul.us"
    "consulting@lassul.us"
    "steuer@lassul.us"
    "versicherung@lassul.us"
    "satellite@lassul.us"
    "doodle@lassul.us"
    "epost@lassul.us"
    "gog@lassul.us"
    "post@lassul.us"
    "buhl@lassul.us"
    "xxx@lassul.us"
    "chess@lassul.us"
    "thainix@lassul.us"
    "volders@lassul.us"
    "namecheap@lassul.us"
    "clanlol@lassul.us"
    "harvest@lassul.us"
    "bauhaus@lassul.us"
    "bahn@lassul.us"
    "framework@lassul.us"
    "bsdex@lassul.us"
    "expressvpn@lassul.us"
    "airvpn@lassul.us"
    "prog@lassul.us"
    "eventphone@lassul.us"
    "startgg@lassul.us"
    "ferdium@lassul.us"
    "start@lassul.us"
    "pad@lassul.us"
    "ups@lassul.us"
    "zalando@lassul.us"
    "trip@lassul.us"
    "git@lassul.us"
    "archive@lassul.us"
    "bybit@lassul.us"
    "okcupid@lassul.us"
    "ing@lassul.us"
    "hornbach@lassul.us"
    "huk@lassul.us"
    "kleinanzeigen@lassul.us"
    "nzbgeek@lassul.us"
    "bonify@lassul.us"
    "bitpanda@lassul.us"
    "schufa@lassul.us"
  ];

in
{
  imports = [
    self.inputs.stockholm.nixosModules.exim-smarthost
  ];

  clan.core.vars.generators."lassul.us-dkim" = {
    files."lassul.us.dkim.priv" = { };
    files."lassul.us.dkim.pub".secret = false;
    migrateFact = "lassul.us-dkim";
    runtimeInputs = with pkgs; [
      coreutils
      openssl
    ];
    script = ''
      openssl genrsa -out "$out"/lassul.us.dkim.priv 2048
      openssl rsa -in "$out"/lassul.us.dkim.priv -pubout -outform der 2>/dev/null | openssl base64 -A > "$out"/lassul.us.dkim.pub
    '';
  };

  krebs.exim-smarthost = {
    enable = true;
    dkim = [
      {
        domain = "lassul.us";
        private_key = config.clan.core.vars.generators."lassul.us-dkim".files."lassul.us.dkim.priv".path;
      }
    ];
    ssl_cert = "/var/lib/acme/mail.lassul.us/fullchain.pem";
    ssl_key = "/var/lib/acme/mail.lassul.us/key.pem";
    primary_hostname = "lassul.us";
    sender_domains = [
      "lassul.us"
    ];
    relay_from_hosts = map (host: host.nets.retiolum.ip6.addr) [
      config.krebs.hosts.aergia
      config.krebs.hosts.ignavia
      config.krebs.hosts.coaxmetal
      config.krebs.hosts.green
      config.krebs.hosts.mors
    ];
    internet-aliases = map (from: { inherit from to; }) mails ++ [
    ];
    system-aliases = [
      {
        from = "mailer-daemon";
        to = "postmaster";
      }
      {
        from = "postmaster";
        to = "root";
      }
      {
        from = "nobody";
        to = "root";
      }
      {
        from = "hostmaster";
        to = "root";
      }
      {
        from = "usenet";
        to = "root";
      }
      {
        from = "news";
        to = "root";
      }
      {
        from = "webmaster";
        to = "root";
      }
      {
        from = "www";
        to = "root";
      }
      {
        from = "ftp";
        to = "root";
      }
      {
        from = "abuse";
        to = "root";
      }
      {
        from = "noc";
        to = "root";
      }
      {
        from = "security";
        to = "root";
      }
      {
        from = "root";
        to = "lass";
      }
    ];
  };
  # msmtp for local submission via SSH (connects to localhost:25)
  environment.systemPackages = [ pkgs.msmtp ];

  krebs.iptables.tables.filter.INPUT.rules = [
    {
      predicate = "-p tcp --dport smtp";
      target = "ACCEPT";
    }
  ];

  security.acme.certs."mail.lassul.us" = {
    group = "lasscert";
    webroot = "/var/lib/acme/acme-challenge";
  };
  users.groups.lasscert.members = [
    "dovecot2"
    "exim"
    "nginx"
  ];
}
