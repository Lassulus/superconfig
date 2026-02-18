{ inputs, ... }:
{
  perSystem =
    {
      lib,
      pkgs,
      ...
    }:
    {
      packages.notmuch =
        let
          # Mailboxes configuration from mail.nix
          mailboxes = {
            afra = [ "to:afra@afra-berlin.de" ];
            c-base = [ "to:c-base.org" ];
            coins = [
              "to:btce@lassul.us"
              "to:coinbase@lassul.us"
              "to:polo@lassul.us"
              "to:bitwala@lassul.us"
              "to:payeer@lassul.us"
              "to:gatehub@lassul.us"
              "to:bitfinex@lassul.us"
              "to:binance@lassul.us"
              "to:bitcoin.de@lassul.us"
              "to:robinhood@lassul.us"
            ];
            dezentrale = [ "to:dezentrale.space" ];
            dhl = [ "to:dhl@lassul.us" ];
            dn42 = [ "to:dn42@lists.nox.tf" ];
            eloop = [ "to:eloop.org" ];
            github = [ "to:github@lassul.us" ];
            gmail = [
              "to:gmail@lassul.us"
              "to:lassulus@gmail.com"
              "lassulus@googlemail.com"
            ];
            india = [
              "to:hillhackers@lists.hillhacks.in"
              "to:hackbeach@lists.hackbeach.in"
              "to:hackbeach@mail.hackbeach.in"
            ];
            kaosstuff = [
              "to:gearbest@lassul.us"
              "to:banggood@lassul.us"
              "to:tomtop@lassul.us"
            ];
            lugs = [ "to:lugs@lug-s.org" ];
            meetup = [ "to:meetup@lassul.us" ];
            nix = [
              "to:nix-devel@googlegroups.com"
              "to:nix@lassul.us"
            ];
            patreon = [ "to:patreon@lassul.us" ];
            paypal = [ "to:paypal@lassul.us" ];
            ptl = [ "to:ptl@posttenebraslab.ch" ];
            retiolum = [ "to:lass@mors.r" ];
            security = [
              "to:seclists.org"
              "to:bugtraq"
              "to:securityfocus@lassul.us"
              "to:security-announce@lists.apple.com"
            ];
            shack = [ "to:shackspace.de" ];
            steam = [ "to:steam@lassul.us" ];
            tinc = [
              "to:tinc@tinc-vpn.org"
              "to:tinc-devel@tinc-vpn.org"
            ];
            wireguard = [ "to:wireguard@lists.zx2c4" ];
            zzz = [
              "to:pizza@lassul.us"
              "to:spam@krebsco.de"
            ];
          };

          notmuchConfig = inputs.wrappers.wrapperModules.notmuch.apply {
            pkgs = pkgs;
            settings = {
              database = {
                path = "Maildir";
                mail_root = "Maildir";
              };
              new.tags = "unread;inbox;";
              search.exclude_tags = "deleted;spam;";
              maildir.synchronize_flags = true;
              user = {
                name = "lassulus";
                primary_email = "lassulus@lassul.us";
                other_email = lib.concatStringsSep ";" (lib.flatten (lib.attrValues mailboxes));
              };
            };
            passthru = {
              mailboxes = mailboxes;
            };
          };
        in
        notmuchConfig.wrapper;
    };
}
