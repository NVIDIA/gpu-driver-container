#!/bin/bash

# Run this script to generate dependabot.yaml
echo '# Please see the documentation for all configuration options:' > .github/dependabot.yml
echo '# https://docs.github.com/github/administering-a-repository/configuration-options-for-dependency-updates' >> .github/dependabot.yml
echo '' >> .github/dependabot.yml

echo 'version: 2' >> .github/dependabot.yml
echo 'updates:' >> .github/dependabot.yml

# Add Go Modules
echo '  - package-ecosystem: "gomod"' >> .github/dependabot.yml
echo '    target-branch: main' >> .github/dependabot.yml
echo '    directory: "/"' >> .github/dependabot.yml
echo '    open-pull-requests-limit: 10' >> .github/dependabot.yml
echo '    schedule:' >> .github/dependabot.yml
echo '      interval: "weekly"' >> .github/dependabot.yml
echo '      day: "sunday"' >> .github/dependabot.yml
echo '    labels:' >> .github/dependabot.yml
echo '    - dependencies' >> .github/dependabot.yml
echo '' >> .github/dependabot.yml

# Add github-actions
echo '  - package-ecosystem: "github-actions"' >> .github/dependabot.yml
echo '    directory: "/"' >> .github/dependabot.yml
echo '    schedule:' >> .github/dependabot.yml
echo '      interval: "daily"' >> .github/dependabot.yml
echo '' >> .github/dependabot.yml

# Add Docker update rule for the /
echo '  - package-ecosystem: "docker"' >> .github/dependabot.yml
echo '    directory: "/"' >> .github/dependabot.yml
echo "    open-pull-requests-limit: 15" >> .github/dependabot.yml
echo '    schedule:' >> .github/dependabot.yml
echo '      interval: "daily"' >> .github/dependabot.yml
echo '' >> .github/dependabot.yml

# Find all Dockerfile directories and add update rule
dockerfiles_found=false # to add blank line
find . -type f -name "Dockerfile" | sed 's|/Dockerfile||' | while read dir; do
  if [ "$dockerfiles_found" = true ]; then
    echo '' >> .github/dependabot.yml
  fi
  echo "  - package-ecosystem: \"docker\"" >> .github/dependabot.yml
  echo "    directory: \"$dir\"" >> .github/dependabot.yml
  echo "    open-pull-requests-limit: 15" >> .github/dependabot.yml
  echo "    schedule:" >> .github/dependabot.yml
  echo "      interval: \"daily\"" >> .github/dependabot.yml
  dockerfiles_found=true
done
