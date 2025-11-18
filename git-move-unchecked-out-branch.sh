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
    ${SELF_NAME} [OPTIONS] local_branch <ref|branch|tag|hash>

Move an unchecked out branch to the given reference
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

    # local branch_name=$(git rev-parse --abbrev-ref HEAD) # TODO Remove if useless

    if [ $# -ne 2 ]; then
        >&2 echo_color 'Error: You have to give a local branch and a target ref!' $COLOR_RED
        exit 2
    fi

    local branch_name="$1"
    local target_ref="$2"

    # Validate |branch_name| exists locally
    local -i is_branch_exist=$(git branch --list --format='%(refname:short)' | grep -c -E "^${branch_name}$")
    if [ $is_branch_exist -eq 0 ]; then
        >&2 echo_color 'Error: You have to give an existing local branch!' $COLOR_RED
        exit 2
    fi

    # Validate the |target_ref| exists, locally or remotely
    local target_hash=$(git rev-parse --short "${target_ref}" 2>/dev/null)
    if [ -z "${target_hash}" ]; then
        >&2 echo_color 'Error: You have to give a valid target!' $COLOR_RED
        exit 2
    fi

    _do "${branch_name}" "${target_ref}"
}

function _do()
{
    local local_branch="$1"
    local target_ref="$2"

    local checked_out_branch=$(git rev-parse --abbrev-ref HEAD)
    # We will not update the given branch if it is the actual checked one.
    if [ "${local_branch}" == "${checked_out_branch}" ]; then
        echo_with_color "The branch \"${branch_name}\" is the current branch" $COLOR_YELLOW
        echo_with_color "Please use 'git reset --hard' to move the current branch to the target ref" $COLOR_YELLOW
    else
        local local_hash=$(git rev-parse --short "${local_branch}")
        local target_hash=$(git rev-parse --short "${target_ref}")
        local target_message="\"${target_ref}\" (${target_hash})"
        if [ "${target_ref}" == "${target_hash}" ]; then
            target_message="\"${target_ref}\""
        fi

        if [ "${local_hash}" == "${target_hash}" ]; then
            echo "Already synch, \"${local_branch}\" (${local_hash}) and ${target_message}"
        else
            echo "Updating the branch \"${local_branch}\" (${local_hash}) to ${target_message}"
            git update-ref "refs/heads/${local_branch}" "${target_ref}"
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
