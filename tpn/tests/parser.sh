#!/usr/bin/env bash
# Regression cases use invented packages/texts; run with bash and POSIX awk.
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cat > "$WORK/input" <<'TEXT'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Files: *
Copyright: 2020 First Author
 2021 Second Author
License: GPL-2+ with distribution exception, Expat and
 BSD-2-clause
 This is license prose, never an identifier.

License:
 Permission is hereby granted, free of charge, to any person obtaining a copy

License:
 LGPL-2.1+
TEXT
awk -v prefix="$WORK/result" -f "$HERE/parse.awk" "$WORK/input"
[ "$(cat "$WORK/result.license")" = 'GPL-2+ with distribution exception, Expat, BSD-2-clause, LGPL-2.1+' ]
[ "$(wc -l < "$WORK/result.holders" | tr -d ' ')" = 2 ]
cat > "$WORK/input" <<'TEXT'
Copyright 2001,
2002 Example Author

Copyright Another Author

This work is copyrighted by Third Author.

This program is distributed under the GNU General Public License, version 3,
or (at your option) any later version.

See /usr/share/common-licenses/GPL-3.

License for more details.

(1) assert copyright on the software
TEXT
awk -v prefix="$WORK/result" -f "$HERE/parse.awk" "$WORK/input"
[ "$(cat "$WORK/result.license")" = 'GPL-3+ (detected)' ]
grep -q '2002 Example Author' "$WORK/result.holders"
grep -q '^Copyright Another Author$' "$WORK/result.holders"
grep -q 'copyrighted by Third Author' "$WORK/result.holders"
! grep -q 'assert copyright' "$WORK/result.holders"
printf '%s\n' 'GPLv2+ and ASL 2.0 and MIT' | awk -f "$HERE/rpm-license.awk" > "$WORK/result"
printf '%s\n' gpl-2.0-or-later apache-2.0 mit > "$WORK/expected"
cmp "$WORK/result" "$WORK/expected"
printf '%s\n' 'GNU Lesser General Public License, version 2.1. GNU General Public License version 3 or later.' > "$WORK/input"
awk -v prefix="$WORK/result" -f "$HERE/parse.awk" "$WORK/input"
[ "$(cat "$WORK/result.license")" = 'LGPL-2.1 (detected), GPL-3+ (detected)' ]
echo 'Parser regressions passed.'
