# Copied from stockholm krebs/5pkgs/simple/kpaste (cc283503).
{
  curl,
  gnused,
  writers,
}:

writers.writeDashBin "kpaste" ''
  ${curl}/bin/curl -sS http://p.r --data-binary @"''${1:--}" \
    -H "Content-Type-Override: ''${KPASTE_CONTENT_TYPE-}" |
  ${gnused}/bin/sed '$ {p;s|http://p.r|https://p.krebsco.de|}'
''
