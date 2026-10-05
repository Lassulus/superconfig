{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      python = pkgs.python3.withPackages (ps: [
        ps.icalendar
        ps.jinja2
        ps.recurring-ical-events
      ]);
      # The VGA font of https://lassul.us, so the booking page matches it.
      static = pkgs.runCommand "book-static" { } ''
        cp -r ${./static} $out
        chmod u+w $out
        cp ${../../configs/websites/lassul.us/Web437_IBM_VGA_8x16.woff} $out/font.woff
      '';
    in
    {
      # Request-and-approve booking page backed by CalDAV (book.lassul.us,
      # configs/book.nix).
      packages.book =
        (pkgs.writeShellApplication {
          name = "book";
          text = ''
            export BOOK_TEMPLATES=${./templates}
            export BOOK_STATIC=${static}
            exec ${python}/bin/python3 ${./book.py} "$@"
          '';
        }).overrideAttrs
          { passthru.usage = builtins.readFile ./usage.kdl; };
    };
}
