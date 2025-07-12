#!/bin/bash
set -e
fail=0
while IFS= read -r -d '' file; do
    if grep -n "^ " "$file" >/dev/null; then
        echo "Space indentation found in $file"
        grep -n "^ " "$file"
        fail=1
    fi
done < <(find . -name '*.gd' -print0)
exit $fail
