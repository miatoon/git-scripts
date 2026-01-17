#!/bin/bash

VERSION='1.0.0'

# Execute this script with 'bash -x SCRIPT' to activate debugging
if [ ${-/*x*/x} == 'x' ]; then
    PS4='+ $(basename ${BASH_SOURCE[0]}):${LINENO} ${FUNCNAME[0]}() |err=$?| \$ '
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
source "${SELF_DIRNAME}/../bash-colors/colors.inc"

function _version()
{
    echo "${SELF_NAME} v${VERSION}"
}

function _help()
{
    cat <<EOF
Usage:
    ${SELF_NAME} [OPTIONS] local_branch

Update an unchecked out branch with its remote tracking branch
You must be in a local clone of a repo.

OPTIONS:
    -v, --version       Display version.
    -h, --help          Display this help.
        --no-color      Remove any color during the display.
EOF
}

OPT_NO_COLOR=false
function _main()
{
    args=$(getopt --options hv --longoptions help,version,no-color --name "${SELF_NAME}" -- "$@")
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
        --no-color)
            OPT_NO_COLOR=true
            shift
        ;;
        --)
            shift
            break
        ;;
        esac
    done

    if [ $# -eq 0 ]; then
        >&2 echo_color 'Error: You have to give a local branch!' $COLOR_RED
        exit 2
    fi

    local branch_name="$1"

    # Validate |branch_name| exists locally
    local -i is_branch_exist=$(git branch --list --format='%(refname:short)' | grep -c -E "^${branch_name}$")
    if [ $is_branch_exist -eq 0 ]; then
        >&2 echo_color 'Error: You have to give an existing local branch!' $COLOR_RED
        exit 2
    fi

    # Get the branch of the given local branch
    # The validity of |remote_branch| is made in the _do() function.
    local remote_branch=$(git rev-parse --abbrev-ref "${branch_name}"@{upstream} 2>/dev/null)
    _do "${branch_name}" "${remote_branch}"
}

function _do()
{
    local local_branch="$1"
    local remote_branch="$2"

    if [ -z "${remote_branch}" ]; then
        # Case of never tracked local branch
        echo_with_color "The branch ${branch_name} is untracked" $COLOR_MAGENTA
    else
        local checked_out_branch=$(git rev-parse --abbrev-ref HEAD)
        # We will not update the given branch if it is the actual checked one.
        if [ "${local_branch}" == "${checked_out_branch}" ]; then
            echo_with_color "The branch \"${branch_name}\" is the current branch" $COLOR_YELLOW
            echo_with_color "Please use 'git pull' to update" $COLOR_YELLOW
        else
            local local_hash=$(git rev-parse --short "${local_branch}")
            local remote_hash=$(git rev-parse --short "${remote_branch}")
            if [ "${local_hash}" == "${remote_hash}" ]; then
                echo "Already synch, \"${local_branch}\" (${local_hash}) and \"${remote_branch}\" (${remote_hash})"
            else
                echo "Updating the branch \"${local_branch}\" (${local_hash}) to \"${remote_branch}\" (${remote_hash})"
                git update-ref "refs/heads/${local_branch}" "${remote_branch}"
            fi
        fi
    fi
}

function echo_with_color()
{
    local text="$1"
    local text_color="$2"

    if $OPT_NO_COLOR; then
        echo "${text}"
    else
        echo_color "${text}" "${text_color}"
    fi
}

_main "$@"
