#!/usr/bin/env bash
# Report/prune the Sonarr library on yellow. Deleting media by hand is a trap:
# Sonarr keeps the series monitored and just grabs everything again on the next
# RSS sync, so the disk fills up a second time. Everything here goes through the
# Sonarr API so the file removal and the unmonitoring stay in sync.
set -euo pipefail

SONARR_URL="${SONARR_URL:-http://127.0.0.1:8989}"
JELLYFIN_DB="${JELLYFIN_DB:-/var/lib/jellyfin/data/jellyfin.db}"
SONARR_CONFIG="${SONARR_CONFIG:-/var/lib/sonarr/.config/NzbDrone/config.xml}"

min_size_gib=0
untouched_only=false
as_json=false
assume_yes=false
add_exclusion=true
cmd=""
targets=()

usage() {
  cat >&2 <<'EOF'
usage: flix-prune list [--untouched] [--min-size GiB] [--json]
       flix-prune delete <series|id>... [--yes] [--keep-exclusion]
       flix-prune unmonitor <series|id>...

env: SONARR_URL, SONARR_API_KEY, SONARR_CONFIG, JELLYFIN_DB
EOF
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
  list | delete | unmonitor)
    [ -z "$cmd" ] || usage
    cmd="$1"
    ;;
  --untouched) untouched_only=true ;;
  --json) as_json=true ;;
  --yes) assume_yes=true ;;
  --keep-exclusion) add_exclusion=false ;;
  --min-size)
    shift
    min_size_gib="${1?--min-size needs an argument}"
    ;;
  --sonarr-url)
    shift
    SONARR_URL="${1?--sonarr-url needs an argument}"
    ;;
  --jellyfin-db)
    shift
    JELLYFIN_DB="${1?--jellyfin-db needs an argument}"
    ;;
  -h | --help) usage ;;
  -*) usage ;;
  *) targets+=("$1") ;;
  esac
  shift
done
[ -n "$cmd" ] || usage

if [ -z "${SONARR_API_KEY:-}" ]; then
  if [ -r "$SONARR_CONFIG" ]; then
    SONARR_API_KEY=$(sed -n 's,.*<ApiKey>\(.*\)</ApiKey>.*,\1,p' "$SONARR_CONFIG")
  else
    echo "flix-prune: no SONARR_API_KEY and $SONARR_CONFIG is unreadable" >&2
    exit 1
  fi
fi

sonarr() {
  local method="$1" path="$2"
  shift 2
  curl -sSf -X "$method" -H "X-Api-Key: $SONARR_API_KEY" \
    -H 'Content-Type: application/json' "$SONARR_URL/api/v3$path" "$@"
}

# One row per series path: last play date, total play count and the number of
# episodes any user ever started. Play state lives per user, and this box has
# ~65 of them, so aggregate over all of them.
watch_tsv() {
  [ -r "$JELLYFIN_DB" ] || return 0
  sqlite3 "file:$JELLYFIN_DB?immutable=1" <<'EOF' 2>/dev/null || true
.mode list
.separator "\t"
.nullvalue ""
select s.Path,
       ifnull(max(ud.LastPlayedDate), ''),
       ifnull(sum(ud.PlayCount), 0),
       count(distinct case
         when ud.Played = 1 or ud.PlayCount > 0 or ud.PlaybackPositionTicks > 0
         then e.Id end)
from BaseItems s
join BaseItems e
  on e.SeriesId = s.Id
 and e.Type = 'MediaBrowser.Controller.Entities.TV.Episode'
left join UserData ud on ud.ItemId = e.Id
where s.Type = 'MediaBrowser.Controller.Entities.TV.Series'
  and s.Path is not null
group by s.Path;
EOF
}

# series objects enriched with watch data, biggest first
series_json() {
  local watch
  watch=$(watch_tsv)
  sonarr GET /series | jq \
    --rawfile watch <(printf '%s' "$watch") \
    --argjson min "$min_size_gib" \
    --argjson untouched "$untouched_only" '
    ($watch | split("\n") | map(select(length > 0) | split("\t"))
      | map({ key: .[0], value: { last: .[1], plays: (.[2] | tonumber), touched: (.[3] | tonumber) } })
      | from_entries) as $w
    | map((.path // "") as $p | {
        id, title, path, monitored, status,
        size: (.statistics.sizeOnDisk // 0),
        files: (.statistics.episodeFileCount // 0),
        last: ($w[$p].last // ""),
        plays: ($w[$p].plays // 0),
        touched: ($w[$p].touched // 0),
        known: ($w | has($p)),
      })
    | map(select(.size >= ($min * 1073741824)))
    | if $untouched then map(select(.touched == 0 and .size > 0)) else . end
    | sort_by(-.size)'
}

human() {
  jq -r '.[] | [
      (.size / 1073741824 | . * 10 | round / 10 | tostring),
      (.files | tostring),
      (if .size > 0 and .files > 0 then (.size / .files / 1073741824 * 100 | round / 100 | tostring) else "-" end),
      (if .touched > 0 then (.touched | tostring) else (if .known then "0" else "?" end) end),
      (.plays | tostring),
      (if .last == "" then "never" else .last[0:10] end),
      (if .monitored then "mon" else "-" end),
      .status,
      .title
    ] | @tsv' |
    awk -F'\t' 'BEGIN {
      printf "%9s %6s %7s %8s %6s %-10s %-4s %-10s %s\n", "SIZE/GiB", "FILES", "GiB/EP", "TOUCHED", "PLAYS", "LAST", "MON", "STATUS", "TITLE"
    } {
      printf "%9s %6s %7s %8s %6s %-10s %-4s %-10s %s\n", $1, $2, $3, $4, $5, $6, $7, $8, $9
      total += $1
    } END {
      printf "%9.1f %6s %7s %8s %6s %-10s %-4s %-10s %s\n", total, "", "", "", "", "", "", "", "(" NR " series)"
    }'
}

resolve() {
  local all="$1" wanted="$2" hit
  hit=$(jq -c --arg w "$wanted" '
    [ .[] | select((.id | tostring) == $w or (.title | ascii_downcase) == ($w | ascii_downcase)) ]' <<<"$all")
  case "$(jq length <<<"$hit")" in
  0)
    echo "flix-prune: no series matching '$wanted'" >&2
    return 1
    ;;
  1) jq -c '.[0]' <<<"$hit" ;;
  *)
    echo "flix-prune: '$wanted' is ambiguous:" >&2
    jq -r '.[] | "  \(.id)\t\(.title)"' <<<"$hit" >&2
    return 1
    ;;
  esac
}

case "$cmd" in
list)
  if $as_json; then series_json; else series_json | human; fi
  ;;
delete | unmonitor)
  [ "${#targets[@]}" -gt 0 ] || usage
  all=$(sonarr GET /series)
  picked=()
  for want in "${targets[@]}"; do
    picked+=("$(resolve "$all" "$want")")
  done

  freed=0
  for row in "${picked[@]}"; do
    size=$(jq -r '.statistics.sizeOnDisk // 0' <<<"$row")
    freed=$((freed + size))
    printf '%s (id %s, %s GiB, %s files, monitored=%s)\n' \
      "$(jq -r .title <<<"$row")" "$(jq -r .id <<<"$row")" \
      "$((size / 1073741824))" \
      "$(jq -r '.statistics.episodeFileCount // 0' <<<"$row")" \
      "$(jq -r .monitored <<<"$row")"
  done
  if [ "$cmd" = delete ]; then
    printf -- '---\nwould free %s GiB across %s series\n' "$((freed / 1073741824))" "${#picked[@]}"
  else
    printf -- '---\nkeeping %s GiB on disk across %s series\n' "$((freed / 1073741824))" "${#picked[@]}"
  fi

  if [ "$cmd" = unmonitor ]; then
    for row in "${picked[@]}"; do
      id=$(jq -r .id <<<"$row")
      jq -c '.monitored = false | .addOptions = {}' <<<"$row" |
        sonarr PUT "/series/$id" --data-binary @- >/dev/null
      echo "unmonitored $(jq -r .title <<<"$row")"
    done
    exit 0
  fi

  if ! $assume_yes; then
    echo "dry-run: re-run with --yes to delete files and remove from Sonarr" >&2
    exit 0
  fi
  for row in "${picked[@]}"; do
    id=$(jq -r .id <<<"$row")
    sonarr DELETE "/series/$id?deleteFiles=true&addImportListExclusion=$add_exclusion" >/dev/null
    echo "deleted $(jq -r .title <<<"$row")"
  done
  ;;
esac
