#!/usr/bin/env bash
set -euo pipefail

owner="${GITHUB_REPOSITORY%%/*}"
owner="$(printf '%s' "$owner" | tr '[:upper:]' '[:lower:]')"
repo="${GITHUB_REPOSITORY#*/}"

if [[ "$repo" == "$owner.github.io" ]]; then
  base="https://$owner.github.io"
else
  base="https://$owner.github.io/$repo"
fi

write_opml() {
  out="$1"
  only="$2"
  {
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<opml version="2.0"><head><title>Social RSS</title></head><body>'
    for spec in "x:feeds-x.txt" "instagram:feeds-instagram.txt"; do
      platform="${spec%%:*}"
      file="${spec#*:}"
      if [[ "$only" != "all" && "$only" != "$platform" ]]; then
        continue
      fi
      while IFS= read -r raw; do
        handle="${raw%%#*}"
        handle="$(printf '%s' "$handle" | tr -d '[:space:]')"
        [[ -z "$handle" ]] && continue
        [[ -f "docs/feeds/$platform/$handle.xml" ]] || continue
        printf '  <outline text="%s: %s" type="rss" xmlUrl="%s/feeds/%s/%s.xml"/>\n' \
          "$platform" "$handle" "$base" "$platform" "$handle"
      done < "$file"
    done
    echo '</body></opml>'
  } > "$out"
  echo "wrote $out"
}

write_opml docs/feeds.opml all
write_opml docs/feeds-x.opml x
write_opml docs/feeds-instagram.opml instagram
