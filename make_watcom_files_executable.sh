#!/bin/sh

# With thanks to https://github.com/open-watcom/open-watcom-v2/discussions/830#discussioncomment-6106091

: "${WATCOM:?Error: WATCOM (Open Watcom installation path) is not set or is empty}"

# Mark 32-bit ELF files in Open Watcom installation as executable
find "${WATCOM}/binl" -type f | while read -r file; do
  if file -b "$file" | grep -qE 'ELF 32-bit.*executable|ELF 64-bit.*executable'; then
    chmod +x "$file"
  fi
done

# Mark 64-bit ELF files in Open Watcom installation as executable
find "${WATCOM}/binl64" -type f | while read -r file; do
  if file -b "$file" | grep -qE 'ELF 32-bit.*executable|ELF 64-bit.*executable'; then
    chmod +x "$file"
  fi
done
