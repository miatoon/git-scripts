#!/bin/bash

if [ $# -ne 1 ]; then
    >&2 echo "Error: You have to give one (and only one) directory to work on."
    exit 2
elif [ ! -d $1/.git ]; then
    >&2 echo "Error: The given directory is not a git clone."
    exit 2
fi

(
    cd "$1"
    url=$(git remote get-url origin)
    is_https_format=$(echo "${url}" | grep -cE 'https://')
    is_git_format=$(echo "${url}" | grep -cE '^git@')

    if [ $is_https_format -eq 0 -a $is_git_format -eq 0 ]; then
        >&2 echo "Error: Only 'https' and 'git' clone url format are supported!"
        exit 2
    fi

    full_repo_name=""
    jq_extractor=""
    if [ $is_https_format -gt 0 ]; then
        full_repo_name=$(echo "${url}" | cut -d'/' -f4-)
        jq_extractor="clone_url"
    elif [ $is_git_format -gt 0 ]; then
        full_repo_name=$(echo "${url}" | cut -d':' -f2-)
        jq_extractor="git_url"
    fi
    full_repo_name=${full_repo_name%.git}
    # declare -p url full_repo_name jq_extractor

    new_url=$(gh api repos/${full_repo_name} --jq ".${jq_extractor}" 2> /dev/null) # TODO is gh really needed here?
    # declare -p new_url
    if [ -z "${new_url}" ]; then
        >&2 echo "Error: Unabled to retrieve the new URL of the repo. Something is wrong with the script."
        exit 2
    fi

    if [ $is_git_format -gt 0 ]; then
        new_url=$(echo "${new_url}" | sed 's,^git://github.com/,git@github.com:,') # TODO handle gitlab too
    fi
    # declare -p new_url

    if [ "${url}" == "${new_url}" ]; then
        echo "Nothing to change, the actual URL '${url}' is the good one."
    else
        echo "Changing the URL"
        echo "  from '${url}'"
        echo "    to '${new_url}'"
        git remote set-url origin "${new_url}"
    fi
)