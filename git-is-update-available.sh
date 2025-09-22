#!/bin/bash

SELF_DIRNAME=$(cd "$(dirname $(type -p "$0"))" ; pwd)
source "${SELF_DIRNAME}/../bash-colors/colors.inc"

echo_color "Looking for an update..." $COLOR_CYAN
lines=$(echo n | git update-git-for-windows 2>&1)
echo "${lines}"

if [[ $(echo "${lines}" | grep -c -F 'is available') > 0 ]]; then
    echo_color "An update is available" $COLOR_YELLOW
    echo_color "Go to \"https://github.com/git-for-windows/build-extra/blob/main/ReleaseNotes.md\" for the release notes" $COLOR_YELLOW
    echo_color "Run 'git update-git-for-windows -y' to make the update" $COLOR_YELLOW
else
    echo_color "You are up-to-date" $COLOR_GREEN
fi
