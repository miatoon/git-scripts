#!/bin/bash

VERSION='1.1.3'

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
    ${SELF_NAME} [OPTIONS] [local_branch]

Tell if a given local branch is:
   * sync with its remote branch
   * ahead of its remote branch
   * behind of its remote branch
   * untracked ; it was never tracked
   * orphan ; its remote branch is dead
Without any given branch, will analyse all your local branches.
Use "HEAD" or "." to analyse only the current local branch.

You must be in a local clone of a repo.

OPTIONS:
    -v, --version       Display version.
    -h, --help          Display this help.
        --orphan        Display only the orphan branches.
        --untracked     Display only the never-tracked branches.
        --unsynched     Display only the unsynchronized branches.
        --no-color      Remove any color during the display.
EOF
}

OPT_ORPHAN=false
OPT_UNTRACKED=false
OPT_UNSYNCHED=false
OPT_NO_COLOR=false
TELL_ORPHAN=true
TELL_UNTRACKED=true
TELL_UNSYNCHED=true
TELL_SYNCHED=true

function _main()
{
    args=$(getopt --options hv --longoptions help,version,orphan,untracked,unsynched,no-color --name "${SELF_NAME}" -- "$@")
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
        --unsynched)
            OPT_UNSYNCHED=true
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
        *)
            >&2 echo_color "Error: Unknown option '$1'" $COLOR_RED
            exit 2
        ;;
        esac
    done

    ($OPT_ORPHAN || $OPT_UNTRACKED || $OPT_UNSYNCHED) && TELL_ORPHAN=false && TELL_UNTRACKED=false && TELL_UNSYNCHED=false && TELL_SYNCHED=false
    $OPT_ORPHAN && TELL_ORPHAN=true
    $OPT_UNTRACKED && TELL_UNTRACKED=true
    $OPT_UNSYNCHED && TELL_UNSYNCHED=true

    if [ $# -ge 1 ]; then
        _do_one_branch "$1"
    else
        _do_all_branches
    fi
}

function _do_one_branch()
{
    local branch_name="$1"
    [ "${branch_name}" == "." ] && branch_name="HEAD"
    if [ "${branch_name}" == "HEAD" ]; then
        branch_name=$(git rev-parse --abbrev-ref HEAD)
        # The |branch_name| can starts with "heads/" in case of a branch upstreamed with
        # anything else than "origin", this is the case for a branch on a forked repo.
        branch_name=${branch_name#heads/}

        if [ "${branch_name}" == "HEAD" ]; then
            # The 'git rev-parse' command return "HEAD" if the current branch is not available / is
            # detached.
            >&2 echo_color 'Error: Unabled to retrieve the name of HEAD. Are you in a "detached HEAD" ?' $COLOR_RED
            exit 2
        fi
    fi

    # Validate |branch_name| exists locally. Do not use the "--format='%(refname:short)'" as it
    # implies a special case for a branch in a forked repo.
    local -i is_branch_exist=$(git branch --list --format='%(refname)' | grep -c -E "^refs/heads/${branch_name}$")
    if [ $is_branch_exist -eq 0 ]; then
        >&2 echo_color 'Error: You have to give an existing local branch!' $COLOR_RED
        exit 2
    fi

    local line=$(local_branch_and_its_tracking_branch_and_its_status "${branch_name}")
    local local_branch=$(echo "${line}" | cut -d';' -f1)
    local remote_branch=$(echo "${line}" | cut -d';' -f2)
    local tracking_info=$(echo "${line}" | cut -d';' -f3)

    # The validity of |remote_branch| is made in the _do() function.
    _do "${local_branch}" "${remote_branch}" "${tracking_info}"
}

function _do_all_branches()
{
    local line
    list_local_branches_and_their_tracking_branch_and_their_status | while read line; do
        local local_branch=$(echo "${line}" | cut -d';' -f1)
        local remote_branch=$(echo "${line}" | cut -d';' -f2)
        local tracking_info=$(echo "${line}" | cut -d';' -f3)
        _do "${local_branch}" "${remote_branch}" "${tracking_info}"
    done
}

function _do()
{
    local local_branch="$1"
    local remote_branch="$2"
    local tracking_info="$3"

    if [ -z "${remote_branch}" ]; then
        # Case of never tracked local branch
        tell_untracked "${local_branch}"
    else
        if [ "${tracking_info}" == "[gone]" ]; then
            tell_orphan "${local_branch}" "${remote_branch}"
        elif [ -z "${tracking_info}" ]; then
            tell_sync "${local_branch}" "${remote_branch}"
        else
            tell_unsync "${local_branch}" "${remote_branch}" "${tracking_info}"
        fi
    fi
}

function list_local_branches_and_their_tracking_branch_and_their_status() {
    # Possible formats returned by '%(upstream:track)'
    #    <empty>: the local branch is synchronized
    #    [gone]: the remote branch was deleted
    #    [ahead X]: the local branch is ahead by X commits
    #    [behind Y]: the local branch is behind by Y commits
    #    [ahead X, behind Y]: the local branch is ahead by X commits but is also behind by Y commits
    #        ; this happens when a commit is made but the branch wasn't fully pulled before that
    #        commit.
    git for-each-ref --format='%(refname:short);%(upstream:short);%(upstream:track)' refs/heads
}

function local_branch_and_its_tracking_branch_and_its_status() {
    git for-each-ref --format='%(refname:short);%(upstream:short);%(upstream:track)' refs/heads/$1
}

function tell_sync()
{
    ! $TELL_SYNCHED && return

    tell_with_color -n "[SYNC]" $COLOR_GREEN
    echo " $1 <-> $2"
}

function tell_unsync()
{
    ! $TELL_UNSYNCHED && return

    tell_with_color -n "[UNSYNC] $3" $COLOR_YELLOW
    echo " $1 <-> $2"
}

function tell_untracked()
{
    ! $TELL_UNTRACKED && return

    tell_with_color -n "[UNTRACKED]" $COLOR_CYAN
    echo " $1"
}

function tell_orphan()
{
    ! $TELL_ORPHAN && return

    tell_with_color -n "[ORPHAN]" $COLOR_YELLOW $STYLE_REVERSE
    echo -n " $1 <-> $2 "
    tell_with_color "" "IS DEAD" $COLOR_YELLOW
}

function tell_with_color()
{
    local echo_opt=$1
    local marker="$2"
    local text_color="$3"
    local text_style="$4"

    if $OPT_NO_COLOR; then
        echo ${echo_opt} "${marker}"
    else
        echo_color ${echo_opt} "${marker}" "${text_color}" "${text_style}"
    fi
}

_main "$@"
