#!/bin/bash
# Verify every reel on the CDN before any guest email goes out.
#   ./check-links.sh            all reels
#   ./check-links.sh ep52       one episode's prefix
#
# jsDelivr refuses files at or over 20,000,000 bytes with a 403 and caches that
# refusal, so an oversize file looks fine locally and fails for the guest.
set -uo pipefail
D="$(cd "$(dirname "$0")" && pwd)/soundbites"
BASE="https://cdn.jsdelivr.net/gh/tarisha-starr/serw-podcast-media@main/soundbites"
FILTER="${1:-}"
bad=0 toobig=0 n=0
for f in "$D"/*.mp4; do
  b="$(basename "$f")"
  [ -n "$FILTER" ] && case "$b" in "$FILTER"*) ;; *) continue ;; esac
  n=$((n+1))
  size=$(stat -f%z "$f")
  if [ "$size" -ge 20000000 ]; then
    printf "TOO BIG  %9d  %s\n" "$size" "$b"; toobig=$((toobig+1))
  fi
  code=$(curl -s -o /dev/null -w '%{http_code}' -r 0-2000 --max-time 45 "$BASE/$b")
  if [ "$code" != "206" ] && [ "$code" != "200" ]; then
    printf "HTTP %s  %s\n" "$code" "$b"; bad=$((bad+1))
  fi
done
echo "checked $n | oversize $toobig | unreachable $bad"
[ "$bad" -eq 0 ] && [ "$toobig" -eq 0 ] && echo "OK to send" || {
  echo "FIX FIRST: re-encode to about 18MB under the SAME filename, push, then"
  echo "  curl -s https://purge.jsdelivr.net/gh/tarisha-starr/serw-podcast-media@main"
  echo "  curl -s https://purge.jsdelivr.net/gh/tarisha-starr/serw-podcast-media@main/soundbites/<file>.mp4"
  exit 1
}
