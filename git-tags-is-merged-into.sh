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
    ${SELF_NAME} [OPTIONS] [branch_or_tag [latest-tags-limit]]

Tell you if all tags were merged (are present) in a branch or a tag.
You must be in a local clone of a repo.

    branch_or_tag       The branch (or tag) in which you'd like to verify the
                        presence of the tags, meaning to verify the tags were
                        merged into that branch (or tag). Can be a remote branch.
                        Default: the current branch.

    latest-tags-limit   A number of how many of the latest tags you'd like to
                        verify.
                        Default: 10

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

    local branch_name='HEAD'
    local -i tags_limit=10 # The shell force this variable to be an integer

    if [ $# -ge 1 ]; then
        branch_name="$1"
        # Validate |branch_name| exist, locally or remotely
        local -i is_branch_exist=$(git branch --list --all --format='%(refname:short)' | grep -c -E "^${branch_name}$")
        local -i is_tag_exist=$(git tag --list | grep -c -E "^${branch_name}$")
        if [ $is_branch_exist -eq 0 -a $is_tag_exist -eq 0 ]; then
            >&2 echo 'Error: You have to give an existing branch or an existing tag!'
            >&2 echo '       Ex: master, origin/master'
            exit 2
        fi

        if [ $# -ge 2 ]; then
            # If |$2| is not a integer, |tags_limit| will be 0 due to the 'local -i' declaration
            tags_limit=$2
            if [ -z "${tags_limit}" -o ${tags_limit} -lt 1 ]; then
                >&2 echo 'Error: "latest-tags-limit" must be a number >0 !'
                >&2 echo '       If you want to give a branch name, then you have to specify the "latest-tags-limit"'
                exit 2
            fi
        fi
    fi

    _do ${tags_limit} ${branch_name}
}

function _do()
{
    local -i tags_limit=$1
    local branch_name=$2

    count_dashed_tags=$(git tag --list | grep -cE '^[0-9]+-[0-9]+-[0-9]+')
    if [ ${count_dashed_tags} -gt 0 ]; then
        tags_list=( $(\
            git tag --list \
            | grep -E '^[0-9]+-[0-9]+-[0-9]+' \
            | tr '-' '.' | sort --version-sort | tr '.' '-' \
            | tail -n ${tags_limit} \
            | xargs \
            ) )
    else
        tags_list=( $(\
            git tag --list \
            | grep -E '^[0-9]+\.[0-9]+\.[0-9]+' \
            | sort --version-sort \
            | tail -n ${tags_limit} \
            | xargs \
            ) )

    fi

    echo "Are the following tags merged into ${branch_name}?"
    local tag
    for tag in ${tags_list[@]}; do
        echo -n "${tag} "
        git merge-base --is-ancestor ${tag} ${branch_name} >&/dev/null
        if [[ $? > 0 ]]; then
            echo_color 'NO' $COLOR_WHITE $STYLE_BOLD $BG_COLOR_RED
        else
            echo_color 'yes' $COLOR_GREEN
        fi
    done
}

_main "$@"
