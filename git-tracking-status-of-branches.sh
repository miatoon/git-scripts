#!/bin/bash

VERSION='1.1.0'

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
    ${SELF_NAME} [OPTIONS]

Display the remote tracking branch of local branches.
   * tells if the local branch was never tracked
   * tells if the local branch is on orphan (when tracking on a dead remote branch)
   * else tells the local branch and its remote tracking branch
You must be in a local clone of a repo.

OPTIONS:
    -v, --version       Display version.
    -h, --help          Display this help.
        --orphan        Display only the orphan branches.
        --untracked     Display only the never-tracked branches.
        --no-color      Remove any color during the display.
EOF
}

OPT_ORPHAN=false
OPT_UNTRACKED=false
OPT_NO_COLOR=false
TELL_ORPHAN=true
TELL_UNTRACKED=true
TELL_TRACKED=true

function _main()
{
    args=$(getopt --options hv --longoptions help,version,orphan,untracked,no-color --name "${SELF_NAME}" -- "$@")
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
        --orphan)
            OPT_ORPHAN=true
            shift
        ;;
        --untracked)
            OPT_UNTRACKED=true
            shift
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

    ($OPT_ORPHAN || $OPT_UNTRACKED) && TELL_ORPHAN=false  && TELL_UNTRACKED=false  && TELL_TRACKED=false
    $OPT_ORPHAN && TELL_ORPHAN=true
    $OPT_UNTRACKED && TELL_UNTRACKED=true

    _do
}

function _do()
{
    local remote_branches=$(list_remote_branches)
    local line
    list_local_branches_and_their_tracking_branch | while read line; do
        local local_branch=$(echo "${line}" | cut -d',' -f1)
        local remote_branch=$(echo "${line}" | cut -d',' -f2)
        if [ -z "${remote_branch}" ]; then
            tell_untracked "${local_branch}"
            # echo "NEVER TRACKED ${local_branch}"
        else
            local tracking_count=$(count_remote_tracking_branches_with_name "${remote_branch}" <<< "${remote_branches}")
            if [ $tracking_count -eq 0 ]; then
                tell_orphan "${local_branch}" "${remote_branch}"
                # echo "ORPHAN ${local_branch} <- ${remote_branch} IS DEAD"
            else
                tell_tracked "${local_branch}" "${remote_branch}"
                # $VERBOSE && echo "TRACKED ${local_branch} <- ${remote_branch}"
            fi
        fi
    done
}

function list_remote_branches()
{
    git branch --list --remote --format='%(refname:short)' | grep -vE 'origin/HEAD'
}

function count_remote_tracking_branches_with_name()
{
    local name=$1
    grep -c -E "^${name}$" -
}

function list_local_branches_and_their_tracking_branch() {
    git for-each-ref 'refs/heads/' --format='%(refname:short),%(upstream:short)'
}

function tell_tracked()
{
    ! $TELL_TRACKED && return

    local branch="$1"
    local tracking_branch="$2"
    tell_with_color -n "[TRACKED]" $COLOR_GREEN
    echo " ${branch} <- ${tracking_branch}"
}

function tell_untracked()
{
    ! $TELL_UNTRACKED && return

    local branch="$1"
    tell_with_color -n "[NEVER TRACKED]" $COLOR_CYAN
    echo " ${branch}"
}

function tell_orphan()
{
    ! $TELL_ORPHAN && return

    local branch="$1"
    local tracking_branch="$2"
    tell_with_color -n "[ORPHAN]" $COLOR_YELLOW
    echo -n " ${local_branch} <- ${tracking_branch} "
    tell_with_color "" "IS DEAD" $COLOR_YELLOW
}

function tell_with_color()
{
    local echo_opt=$1
    local marker="$2"
    local text_color="$3"

    if $OPT_NO_COLOR; then
        echo ${echo_opt} "${marker}"
    else
        echo_color ${echo_opt} "${marker}" "${text_color}"
    fi
}

_main "$@"
