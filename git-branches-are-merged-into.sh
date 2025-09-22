#!/bin/bash

VERSION='0.1.2'

# Execute this script with 'bash -x SCRIPT' to activate debugging
if [ ${-/*x*/x} == 'x' ]; then
    PS4='+ $(basename ${BASH_SOURCE[0]}):${LINENO} ${FUNCNAME[0]}() |err=$?| \$ '
fi
# set -e  # Fail on first error

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
    ${SELF_NAME} [OPTIONS] [target-branch [remote-branch]]

Tell you if all remote branches were merged (are present) in the target branch.
If the remote branch is specified, only check this branch.
You must be in a local clone of a repo.

    target-branch       The branch in which you'd like to verify the presence
                        of the remote branches, meaning to verify the remote
                        branches were merged into that branch. Can be a remote
                        branch.
                        Default: the current branch.
    remote-branch       Make the verification for this branch only. Must be a
                        remote branch (beginning with 'origin/')

OPTIONS:
    -v, --version       Display version.
    -h, --help          Display this help.
EOF
}

function _main()
{
    args=$(getopt --options hv --longoptions help,version --name "${SELF_NAME}" -- "$@")
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

    local target_branch='HEAD'
    local remote_branch=''
    local -i is_exist=0

    if [ $# -ge 1 ]; then
        target_branch="$1"
        # Validate |target_branch| exists, locally or remotely
        if [ "${target_branch#origin/}" == "${target_branch}" ]; then
            # Check for a local branch
            is_exist=$(git branch --list --format="%(refname:short)" | grep -c -F "${target_branch}")
        else
            # Check for a remote branch
            is_exist=$(git branch --list --remote --format="%(refname:short)" | grep -c -F "${target_branch}")
        fi
        if [ $is_exist -eq 0 ]; then
            >&2 echo 'Error: You have to give an existing local or remote branch !'
            >&2 echo '       Ex: master, origin/master'
            exit 2
        fi

        if [ $# -ge 2 ]; then
            remote_branch="$2"
            # Validate |remote_branch| exists and is a remote branch
            is_exist=$(git branch --list --remote --format="%(refname:short)" | grep -c -F "${remote_branch}")
            if [ $is_exist -eq 0 ]; then
                >&2 echo 'Error: "remote-branch" must exist and be a remote branch !'
                exit 2
            fi
        fi
    fi

    _do ${target_branch} ${remote_branch}
}

function _do()
{
    local target_branch="$1"
    local remote_branch="$2"

    local -a remote_branches=()
    if [ "${remote_branch}" == "" ]; then
        # Fetch all the remote branches, excluding "origin/HEAD" and the target
        # branch. Use the "(origin/)?" in the grep regex in case the given
        # target branch is a remote branch.
        #
        # Fetching by commit date: the committer date is used to sort by the more recent date, then
        # the date is removed because we don't used it afterward.
        remote_branches=( \
            $(git branch --list --remote --format="%(committerdate:iso);%(refname:short)" | \
                sort -r | cut -d';' -f2- | \
                grep -v "origin/HEAD" | \
                grep -v -E "^(origin/)?${target_branch}$" \
            ) \
        )
    else
        remote_branches=( ${remote_branch} )
    fi

    echo "Are the following remote branches merged into ${target_branch}?"
    local remote
    for remote in ${remote_branches[@]}; do
        echo -n "${remote} "
        git merge-base --is-ancestor ${remote} ${target_branch} >&/dev/null
        if [[ $? > 0 ]]; then
            echo_color 'NO' $COLOR_WHITE $STYLE_BOLD $BG_COLOR_RED
        else
            echo_color 'yes' $COLOR_GREEN
        fi
    done
}

_main "$@"
