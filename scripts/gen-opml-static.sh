#!/usr/bin/env bash
set -euo pipefail

owner="${GITHUB_REPOSITORY%%/*}"
repo="${GITHUB_REPOSITORY#*/}"

if [[ "$repo" == "$owner.github.io" ]]; then
  base="https://$owner.github.io"
else
  base="https://$owner.github.io/$repo"
fi

out="docs/feeds.opml"
{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<opml version="2.0"><head><title>Social RSS</title></head><body>'
  for spec in "x:feeds-x.txt" "instagram:feeds-instagram.txt"; do
    platform="${spec%%:*}"
    file="${spec#*:}"
    while IFS= read -r raw; do
      handle="${raw%%#*}"
      handle="$(printf '%s' "$handle" | tr -d '[:space:]')"
      [[ -z "$handle" ]] && continue
      printf '  <outline text="%s: %s" type="rss" xmlUrl="%s/feeds/%s/%s.xml"/>\n' \
        "$platform" "$handle" "$base" "$platform" "$handle"
    done < "$file"
  done
  echo '</body></opml>'
} > "$out"

echo "wrote $out"
