# Copied from stockholm krebs/5pkgs/simple/nomads-cloud (cc283503).
{
  callPackage,
  writers,
  coreutils,
  curl,
  jq,
  findutils,
  imagemagick,
}:
let
  grib2json = callPackage ./grib2json.nix { };
in
writers.writeDashBin "nomads-cloud" ''
  prefix=$(mktemp -d)
  grib_path=$prefix/clouds.grib
  json_path=$prefix/clouds.json
  pgm_path=$prefix/clouds.pgm
  png_path=$1

  mkdir -p "$prefix"

  date=$(${coreutils}/bin/date +%Y%m%d)
  for hour in 18 12 06 00; do
    url="https://nomads.ncep.noaa.gov/cgi-bin/filter_gfs_0p25_1hr.pl?file=gfs.t''${hour}z.pgrb2.0p25.anl&lev_entire_atmosphere_%5C%28considered_as_a_single_layer%5C%29=on&var_CWAT=on&leftlon=-180&rightlon=180&toplat=90&bottomlat=-90&dir=%2Fgfs.''${date}%2F''${hour}%2Fatmos"
    echo "$url"
    ${curl}/bin/curl -fsS "$url" > "$grib_path"
    if [ "$?" -eq 0 ]; then
      break
    fi
  done
  ${grib2json}/bin/grib2json --data "$grib_path" > "$json_path"

  width=$(${jq}/bin/jq '.[0].header.nx' < "$json_path")
  height=$(${jq}/bin/jq '.[0].header.ny' < "$json_path")

  # The maximum gray value.  Must be bigger than 0 and less than 65536.
  maxval=1000

  # pgm - Netpbm grayscale image format
  # http://netpbm.sourceforge.net/doc/pgm.html
  {
    echo P2
    echo "$width $height"
    echo "$maxval"
    cat "$json_path" |
    ${jq}/bin/jq --argjson maxval "$maxval" -c '
      ((.[0].data[]) * $maxval | round)
    ' |
    ${findutils}/bin/xargs -n "$width"
  } > "$pgm_path"

  ${imagemagick}/bin/convert -roll +50% "$pgm_path" "$png_path"

  rm -r "$prefix"
''
