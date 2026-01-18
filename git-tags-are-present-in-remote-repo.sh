#!/bin/bash

VERSION='1.0.0'

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
    ${SELF_NAME} [OPTIONS] [remote-name]

Tell you if tags were pushed (are present) in the remote repo.
You must be in a local clone of a repo.

    remote-name         The name of the remote repo. Default to "origin".

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

    local remote_name='origin'
    if [ $# -ge 1 ]; then
        remote_name="$1"
        # Validate |remote_name| exists and that the local repo is set to
        # pull/fetch with it.
        git remote show ${remote_name} >& /dev/null
        local errcode=$?
        if [ ${errcode} -ne 0 ]; then
            >&2 echo 'Error: You have to give a remote repo name that is linked to this local repo !'
            >&2 echo '       Get them with "git remote"'
            exit 2
        fi
    fi

    _do ${remote_name}
}

function _do()
{
    local remote_name=$1

    local repo=$(git remote get-url ${remote_name}) # TODO to verify
    repo=${repo%.git}

    # Local tags are stored under the "refs/tags/" in the .git folder. By using
    # the "find" command we are supporting tags which are prefixed with a
    # subfolder name ; and by using "sed" after, we are keeping the
    # "subfolder/tag_name" intact.
    local local_tags_list=( $(find .git/refs/tags/ -type f | sed 's,.git/refs/tags/,,') )
    # declare -p local_tags_list
    if [ ${#local_tags_list[@]} -eq 0 ]; then
        # No local tags. There's no need to go further.
        echo_color 'No local tags detected' $COLOR_GREEN
        return
    fi

    local remote_tags_list=( $(gh api --paginate "repos/${repo}/tags" --jq '.[] | .name') )
    # declare -p remote_tags_list

    echo "Are the following local tags present in '${remote_name}'?"
    local tag
    for tag in ${local_tags_list[@]}; do
        echo -n "${tag} "
        if [[ " ${remote_tags_list[@]} " =~ " ${tag} " ]]; then
            echo_color 'yes' $COLOR_GREEN
        else
            echo_color 'NO' $COLOR_WHITE $STYLE_BOLD $BG_COLOR_RED
        fi
    done
}

_main "$@"
