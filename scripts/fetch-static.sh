#!/usr/bin/env bash
set -euo pipefail

platform="${1:?usage: fetch-static.sh x|instagram}"
case "$platform" in
  x)
    list="feeds-x.txt"
    route="/twitter/user"
    ;;
  instagram)
    list="feeds-instagram.txt"
    route="/instagram/user"
    ;;
  *)
    echo "unknown platform: $platform" >&2
    exit 2
    ;;
esac

mkdir -p "docs/feeds/$platform"
total=0
failed=0

# Remove XML files for handles that are no longer in the list.
keep_file="$(mktemp)"
trap 'rm -f "$keep_file"' EXIT
while IFS= read -r raw; do
  handle="${raw%%#*}"
  handle="$(printf '%s' "$handle" | tr -d '[:space:]')"
  [[ -z "$handle" ]] && continue
  printf '%s.xml\n' "$handle" >> "$keep_file"
done < "$list"
for f in "docs/feeds/$platform"/*.xml; do
  [[ -e "$f" ]] || continue
  base="$(basename "$f")"
  if ! grep -qxF "$base" "$keep_file"; then
    rm -f "$f"
    echo "REMOVED stale $platform/$base"
  fi
done

while IFS= read -r raw; do
  handle="${raw%%#*}"
  handle="$(printf '%s' "$handle" | tr -d '[:space:]')"
  [[ -z "$handle" ]] && continue

  total=$((total + 1))
  tmp="docs/feeds/$platform/$handle.xml.tmp"

  if curl -fsS -m 45 "http://localhost:1200$route/$handle" -o "$tmp"; then
    if python3 -c 'import sys, xml.etree.ElementTree as ET; ET.parse(sys.argv[1])' "$tmp"; then
      mv "$tmp" "docs/feeds/$platform/$handle.xml"
      echo "OK $platform/$handle"
    else
      echo "INVALID XML $platform/$handle" >&2
      rm -f "$tmp"
      failed=$((failed + 1))
    fi
  else
    echo "FETCH FAILED $platform/$handle" >&2
    echo "--- response body ---" >&2
    curl -sS -m 45 -D - "http://localhost:1200$route/$handle" 2>&1 | head -40 >&2 || true
    echo "--- rsshub logs ---" >&2
    docker logs --tail 40 rsshub 2>&1 || true
    echo "--- end diagnostics ---" >&2
    rm -f "$tmp"
    failed=$((failed + 1))
  fi

  # Spread requests to look like normal browsing: ~10s average, 7-13s range.
  sleep $((7 + RANDOM % 7))
done < "$list"

echo "total: $total, failures: $failed"
if [[ "$total" -gt 0 && "$failed" -eq "$total" ]]; then
  exit 1
fi
