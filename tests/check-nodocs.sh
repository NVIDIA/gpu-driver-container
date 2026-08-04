#!/usr/bin/env bash
# Fail if a dnf transaction that installs into a RHEL image is missing --nodocs.
#
# Documentation installed at image build ends up in the layers we ship, where it
# grows the image and gets picked up by CI scanners. Every install and update in
# these build contexts therefore has to pass --nodocs, and this catches the ones
# that are added later without it.
#
# Continuation lines are joined first, so a command split across lines is still
# seen as one command. Each joined command is then split on &&, ||, ; and | so a
# chain only passes if every transaction in it carries the flag.
#
# Scope. Only the files that put content into the image are checked:
#
#   - the RHEL driver and vGPU Manager Dockerfiles and install.sh
#   - not rhel*/precompiled, which persists the same setting through
#     `dnf config-manager --nodocs --save` instead of per-command flags
#   - not nvidia-driver or ocp_dtk_entrypoint, whose dnf calls run in the
#     started container rather than at image build
#
# Commands that do not install packages, such as module enable, versionlock,
# config-manager, remove, autoremove and clean, are not matched.
#
# Run from the repository root:
#   ./tests/check-nodocs.sh

set -eu

cd "$(dirname "$0")/.."

TARGETS="
rhel8/Dockerfile
rhel9/Dockerfile
rhel10/Dockerfile
rhel8/install.sh
rhel9/install.sh
rhel10/install.sh
vgpu-manager/rhel8/Dockerfile
vgpu-manager/rhel9/Dockerfile
"

find_offenders() {
  awk '
    # dnf, any number of short or long flags, then a verb that opens a
    # transaction. Applied to one command at a time.
    function is_transaction(text) {
      return text ~ /(^|[^-[:alnum:]_])dnf([[:space:]]+-[^[:space:]]+)*[[:space:]]+(install|update|upgrade|reinstall|downgrade)([[:space:]]|$)/
    }

    function report(command, lineno,   parts, count, i) {
      if (command ~ /^[[:space:]]*#/)
        return
      count = split(command, parts, /&&|\|\||;|\|/)
      for (i = 1; i <= count; i++)
        if (is_transaction(parts[i]) && parts[i] !~ /--nodocs/) {
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", parts[i])
          print lineno ": " parts[i]
        }
    }

    {
      if (buffer == "")
        start = NR
      text = $0
      continued = (text ~ /\\[[:space:]]*$/)
      sub(/\\[[:space:]]*$/, "", text)
      buffer = (buffer == "" ? text : buffer " " text)
      if (continued)
        next
      report(buffer, start)
      buffer = ""
    }

    END {
      if (buffer != "")
        report(buffer, start)
    }
  ' "$1"
}

status=0

for file in $TARGETS; do
  [ -f "$file" ] || { echo "check-nodocs.sh: missing $file" >&2; status=1; continue; }

  offenders=$(find_offenders "$file")

  if [ -n "$offenders" ]; then
    status=1
    while IFS= read -r line; do
      printf '%s:%s\n' "$file" "$line"
    done <<< "$offenders"
  fi
done

if [ "$status" -ne 0 ]; then
  cat >&2 <<'EOF'

dnf transactions above are missing --nodocs.

Add it so the documentation is never written into the image:

    dnf install -y --nodocs <packages>
    dnf update -y --nodocs

If a command genuinely should keep documentation, exclude the file in
tests/check-nodocs.sh and say why.
EOF
  exit 1
fi

echo "all dnf transactions in the RHEL build contexts pass --nodocs"
