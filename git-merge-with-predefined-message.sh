#!/bin/bash

VERSION='1.2.0'

# Execute this script with 'bash -x SCRIPT' to activate debugging
if [ ${-/*x*/x} == 'x' ]; then
    PS4='+ ${BASH_SOURCE[0]}:${LINENO} ${FUNCNAME[0]}() |err=$?| \$ '
fi
set -e  # Fail on first error

SELF_NAME="$0"
if [[ "${MACHTYPE}" =~ "msys" ]]; then
    SELF_NAME="${SELF_NAME//\\//}"
    SELF_NAME="${SELF_NAME/[A-Z]://C}"
fi
SELF_NAME="${SELF_NAME#\.}"
SELF_NAME="${SELF_NAME##/*/}"
SELF_NAME="${SELF_NAME#/}"
SELF_NAME="${SELF_NAME%.sh}"
SELF_DIRNAME=$(cd "$(dirname $(type -p "$0"))" ; pwd)

# Includes
source "${SELF_DIRNAME}/colors.inc"

function _version()
{
    echo "${SELF_NAME} v${VERSION}"
}

function _help()
{
    cat <<EOF
Usage:
    ${SELF_NAME} [OPTIONS] branch_or_tag -- [ARGS]

Merge the given branch or tag in the current branch with a predefined message.
  In case the given branch is 'origin/master' or 'master', the predefined
  messagewill be something like "Sync with master".

    branch_or_tag   The branch (local or remote) or the tag to merge into the
                    current branch.

OPTIONS:
    -v, --version   Display version.
    -h, --help      Display this help.
ARGS:
    All the other arguments will be pass to the 'git merge' command.

EOF
}

function _main()
{
    local args=$(getopt --options hv --longoptions help,version --name "${SELF_NAME}" -- "$@")
    if [ $? -ne 0 ]; then
        >&2 echo "Error: Invalid options"
        exit 2
    fi
    eval set -- "${args}"
    while true; do
        case "$1" in
        -v|--version)
            _version
            exit 0
        ;;
        -h|--help)
            _help
            exit 0
        ;;
        --)
            shift
            break
        ;;
        esac
    done

    if [ $# -eq 0 -o "$1" == "" ]; then
        >&2 echo_color 'Error: You have to give a branch name or a tag name!' $COLOR_RED
        exit 2
    fi

    local branch_to_merge="$1"
    shift
    local other_args="$@"

    local is_branch_exist=$(git branch --all --format='%(refname:short)' | grep -c -E "^${branch_to_merge}$")
    local is_tag_exist=$(git tag --list | grep -c -E "^${branch_to_merge}$")
    if [ $is_branch_exist -eq 0 -a $is_tag_exist -eq 0 ]; then
        >&2 echo_color "Error: The given name '${branch_to_merge}' is neither a branch nor a tag!" $COLOR_RED
        exit 2
    fi

    _merge_with_predefined_message "${branch_to_merge}" $is_tag_exist
}

function _merge_with_predefined_message()
{
    local branch_to_merge=$1
    local branch_to_merge_no_origin=${branch_to_merge#origin/}
    local is_a_tag=$2
    local current_branch=$(git branch --show-current)

    local type_str="branch"
    [ $is_a_tag -ge 1 ] && type_str="tag"

    local err=0
    if [ "${branch_to_merge_no_origin}" == "master" ]; then  # TODO handle "main" branch
        echo_color "Synching with master, with predefined message..." $COLOR_YELLOW
        git merge --no-ff "${branch_to_merge}" -m "Sync with '${branch_to_merge_no_origin}'" ${other_args}
        err=$?
    else
        echo_color "Merging with predefined message..." $COLOR_YELLOW
        git merge --no-ff "${branch_to_merge}" -m "Merge ${type_str} '${branch_to_merge_no_origin}' into '${current_branch}'" ${other_args}
        err=$?
    fi
    if [[ $err == 0 ]]; then
        echo_color "Done" $COLOR_GREEN
    else
        echo_color "Warning: something happened, look at the git messages above" $BG_COLOR_MAGENTA
        exit $err
    fi
}

_main "$@"
