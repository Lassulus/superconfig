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
          notmuchConfig = inputs.wrappers.wrapperModules.notmuch.apply {
            pkgs = pkgs;
            settings = {
              database = {
                path = "Maildir";
                mail_root = "Maildir";
              };
              new.tags = "unread;inbox;";
              new.ignore = "fts-flatcurve";
              search.exclude_tags = "deleted;spam;";
              maildir.synchronize_flags = true;
              user = {
                name = "lassulus";
                primary_email = "lassulus@lassul.us";
                other_email = lib.concatStringsSep ";" [
                  "lass@lassul.us"
                  "lassulus@c-base.org"
                  "lassulus@gmail.com"
                  "lassulus@googlemail.com"
                ];
              };
            };
            passthru = { };
          };
        in
        notmuchConfig.wrapper;
    };
}
