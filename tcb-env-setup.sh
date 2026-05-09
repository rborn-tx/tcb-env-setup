#!/usr/bin/env bash

_tcb_check_sourced() {
    _TCB_SOURCED=false

    if [ -n "${ZSH_EVAL_CONTEXT}" ]; then
        # zsh
        case ${ZSH_EVAL_CONTEXT} in *:file) _TCB_SOURCED=true;; esac
    elif [ -n "${KSH_VERSION}" ]; then
        # ksh
        [ "$(cd "$(dirname -- "$0")" && pwd -P)/$(basename -- "$0")" != "$(cd "$(dirname -- ${.sh.file})" && pwd -P)/$(basename -- ${.sh.file})" ] && _TCB_SOURCED=true
    elif [ -n "${BASH_VERSION}" ]; then
        # bash
        (return 0 2>/dev/null) && _TCB_SOURCED=true
    else
        # All other shells: examine $0 for known shell binary filenames
        case ${0##*/} in sh|dash) _TCB_SOURCED=true;; esac
    fi

    if [ "${_TCB_SOURCED}" = "false" ]; then
        echo "Error: don't run $0, source it."
        exit 1
    fi
}

_tcb_cleanup() {
    unset _TCB_AUTO_MODE
    unset _TCB_CHOSEN_TAG
    unset _TCB_DOCKER_EXTRA
    unset _TCB_INTERACTIVE_FLAGS
    unset _TCB_LATEST_LOCAL
    unset _TCB_LATEST_REMOTE
    unset _TCB_LOCAL_TAGS
    unset _TCB_NETWORK
    unset _TCB_PULL_REMOTE
    unset _TCB_REMOTE_TAGS
    unset _TCB_SCRIPT_PATH
    unset _TCB_SOURCED
    unset _TCB_STORAGE
    unset _TCB_TAG
    unset _TCB_UNDER_WINDOWS
    unset _TCB_USER_TAG
    unset _TCB_VOLUMES
}

_tcb_teardown() {
    {
        unset -f _tcb_check_sourced
        unset -f _tcb_check_updated
        unset -f _tcb_choose_tag
        unset -f _tcb_define_alias
        unset -f _tcb_detect_platform
        unset -f _tcb_detect_tty
        unset -f _tcb_get_latest_tag
        unset -f _tcb_init_defaults
        unset -f _tcb_load_completion_if_latest
        unset -f _tcb_load_tags
        unset -f _tcb_main
        unset -f _tcb_parse_args
        unset -f _tcb_print_final_messages
        unset -f _tcb_pull_if_needed
        unset -f _tcb_set_script_path
        unset -f _tcb_usage
        unset -f _tcb_validate_inputs
    } 2>/dev/null
}

_tcb_usage() {
    cat <<EOF
Usage: source tcb-env-setup.sh [OPTIONS] [-- <docker_options>]

Optional arguments:
  -a <value>: select auto mode
      With this flag enabled the script will automatically run with no need
      for user input. Valid values for <value> are either remote or local.

      When "-a remote" is passed, the script will automatically use the
      latest version of TorizonCore Builder online, with no consideration
      for any local versions that may exist.

      When "-a local" is passed the script will automatically use the latest
      version of TorizonCore Builder found locally, with no consideration to
      what may be online. This flag is mutually exclusive with the -t flag.

  -t <version tag>: select tag mode
      With this flag enabled the script will automatically run with no need
      for user input. Valid values for <version tag> can be found online:
      https://registry.hub.docker.com/r/torizon/torizoncore-builder/tags?page=1&ordering=last_updated.
      Whatever <version tag> is provided will then be pulled from online.
      This flag is mutually exclusive with the -a flag.

  -d: disable volumes
      With this flag enabled the script will setup torizoncore-builder
      without Docker volumes meaning some torizoncore-builder commands will
      require additional directories to be passed as arguments. By default
      with this flag excluded torizoncore-builder is setup with Docker
      volumes.

  -s: select storage directory or Docker volume
      Internal storage directory or Docker volume that TorizonCore Builder
      should use to keep its state information and image customizations.
      It must be an absolute directory or a Docker volume name. If this
      flag is not set, the "storage" Docker volume will be used.

  -n: do not enable "host" network mode.
      Under Linux the tool runs in "host" network mode by default allowing
      it to operate as a server without explicit port publishing. Under
      Windows this mode of operation is always disabled requiring port
      publishing to be set up if the tool is to act as a server. This flag
      disables the default behavior (which is relevant under Linux).

  -- <docker_options>: extra options to be passed to "docker run".
       Parameters after -- are simply forwarded to the "docker run"
       invocation in the alias that the script creates.

  -h: help
       Prints usage information.
EOF
}

_tcb_check_updated() {
    [ ! -f "$1" ] && return

    local target_url="https://raw.githubusercontent.com/toradex/tcb-env-setup/master/tcb-env-setup.sh"

    local status_code
    status_code=$(curl -sL -o tcb-env-setup.sh.tmp -w '%{http_code}' "${target_url}")
    local remote_md5sum
    remote_md5sum=$(md5sum tcb-env-setup.sh.tmp | cut -d ' ' -f 1)
    local local_md5sum
    local_md5sum=$(md5sum "$1" | cut -d ' ' -f 1)
    rm tcb-env-setup.sh.tmp

    if [ "${status_code}" -eq 200 -a "${remote_md5sum}" != "${local_md5sum}" ]; then
        cat <<EOF
WARNING: This setup script is outdated. To update it, run:
   $ wget -O tcb-env-setup.sh ${target_url}

EOF
    fi
}

_tcb_detect_platform() {
    _TCB_UNDER_WINDOWS=false
    if uname -r | grep -i "microsoft" > /dev/null; then
        _TCB_UNDER_WINDOWS=true
    fi
}

_tcb_detect_tty() {
    _TCB_INTERACTIVE_FLAGS=""
    if [[ -t 0 && -t 1 ]]; then
        _TCB_INTERACTIVE_FLAGS="-it"
    fi
}

_tcb_init_defaults() {
    _TCB_VOLUMES=" -v /deploy "
    _TCB_STORAGE="storage"
    _TCB_NETWORK=" --network=host "
    if [ "${_TCB_UNDER_WINDOWS}" = "true" ]; then
        _TCB_NETWORK=" "
    fi
}

_tcb_parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a)
                _TCB_AUTO_MODE=$2
                [ "$2" ] || _TCB_AUTO_MODE="empty"
                shift
                shift
                ;;
            -t)
                _TCB_USER_TAG="$2"
                [ "$2" ] || _TCB_USER_TAG="empty"
                shift
                shift
                ;;
            -s)
                _TCB_STORAGE="$2"
                [ "$2" ] || _TCB_STORAGE="empty"
                shift
                shift
                ;;
            -d)
                _TCB_VOLUMES=" "
                shift
                ;;
            -n)
                _TCB_NETWORK=" "
                shift
                ;;
            --)
                shift
                break
                ;;
            -h|*)
                _tcb_usage
                _tcb_cleanup
                return 1
                ;;
        esac
    done

    _TCB_DOCKER_EXTRA="$*"
    return 0
}

_tcb_set_script_path() {
    if [ -z "${ZSH_VERSION-}" ]; then
        _TCB_SCRIPT_PATH="${PWD}/${BASH_SOURCE[0]}"
    else
        _TCB_SCRIPT_PATH="${(%):-%x}"
    fi
}

_tcb_validate_inputs() {
    if [[ ${_TCB_AUTO_MODE} = "empty" ]] || [[ ${_TCB_USER_TAG} = "empty" ]] || \
       [[ ${_TCB_STORAGE} = "empty" ]]; then
        _tcb_usage
        _tcb_cleanup
        return 1
    fi

    if [[ -n ${_TCB_AUTO_MODE} && -n ${_TCB_USER_TAG} ]]; then
        echo "Error: -a and -t are mutually exclusive. Please only use one flag at a time."
        _tcb_cleanup
        return 1
    fi

    if [[ -n ${_TCB_AUTO_MODE} && ${_TCB_AUTO_MODE} != "local" && ${_TCB_AUTO_MODE} != "remote" ]]; then
        echo "Error: unrecognized value ${_TCB_AUTO_MODE} for -a"
        _tcb_cleanup
        return 1
    fi

    if [[ ${_TCB_STORAGE} != /* && ! ${_TCB_STORAGE} =~ ^[a-zA-Z][a-zA-Z0-9_.-]*$ ]]; then
        echo "Error: \"${_TCB_STORAGE}\" storage must be an absolute directory or a valid Docker volume name."
        _tcb_cleanup
        return 1
    fi

    if [ "${_TCB_UNDER_WINDOWS}" = "true" -a $# -eq 0 ]; then
        echo "Warning: If you intend to use torizoncore-builder as a server (listening to ports), then you should pass extra parameters to \"docker run\" (via the -- switch)."
    fi

    return 0
}

_tcb_load_tags() {
    _TCB_REMOTE_TAGS=$(curl -L -s 'https://registry.hub.docker.com/v2/namespaces/torizon/repositories/torizoncore-builder/tags' \
                           | sed -n -e 's/\("name"\) *: *\("[^"]\+"\)/\n\1:\2\n/gp' \
                           | sed -n -e 's/"name":"\([^"]\+\)"/\1/p')
    _TCB_LOCAL_TAGS=$(docker images "torizon/torizoncore-builder" 2>/dev/null \
                          | sed -n 's/^.*torizoncore-builder\s\+\([0-9]\+\).*$/\1/p')
}

_tcb_get_latest_tag() {
    local _tcb_latest="" _tcb_tag=""
    for _tcb_tag in $(echo "$@"); do
        if [[ ${_tcb_tag} != *"."* ]]; then
            if [[ ${_tcb_tag} -gt ${_tcb_latest} ]]; then
                _tcb_latest=${_tcb_tag}
            fi
        fi
    done
    [ -n "${_tcb_latest}" ] || return 1
    echo "${_tcb_latest}"
}

_tcb_choose_tag() {
    local yn

    _TCB_LATEST_REMOTE=$(_tcb_get_latest_tag "${_TCB_REMOTE_TAGS}")

    if [[ -z ${_TCB_LOCAL_TAGS} && -z ${_TCB_AUTO_MODE} && -z ${_TCB_USER_TAG} ]]; then
        echo "TorizonCore Builder is not installed. Pulling the latest version from Docker Hub..."
        _TCB_PULL_REMOTE=true
        _TCB_CHOSEN_TAG=${_TCB_LATEST_REMOTE}

    elif [[ -n ${_TCB_LOCAL_TAGS} && -z ${_TCB_AUTO_MODE} && -z ${_TCB_USER_TAG} ]]; then
        _TCB_LATEST_LOCAL=$(_tcb_get_latest_tag "${_TCB_LOCAL_TAGS}")
        echo -n "You may have an outdated version installed. Would you like to check for updates online? [y/n] "
        read -r yn
        case ${yn} in
            [Yy]*)
                _TCB_PULL_REMOTE=true
                _TCB_CHOSEN_TAG=${_TCB_LATEST_REMOTE}
                ;;
            [Nn]*)
                _TCB_PULL_REMOTE=false
                _TCB_CHOSEN_TAG=${_TCB_LATEST_LOCAL}
                ;;
            *)
                echo "Please answer yes or no."
                _tcb_cleanup
                return 1
                ;;
        esac

    elif [[ ${_TCB_AUTO_MODE} == "local" ]]; then
        _TCB_LATEST_LOCAL=$(_tcb_get_latest_tag "${_TCB_LOCAL_TAGS}")
        if [[ -z ${_TCB_LATEST_LOCAL} ]]; then
            echo "Error: no local versions found!"
            _tcb_cleanup
            return 1
        fi
        _TCB_PULL_REMOTE=false
        _TCB_CHOSEN_TAG=${_TCB_LATEST_LOCAL}

    elif [[ ${_TCB_AUTO_MODE} == "remote" ]]; then
        _TCB_PULL_REMOTE=true
        _TCB_CHOSEN_TAG=${_TCB_LATEST_REMOTE}

    elif [[ -n ${_TCB_USER_TAG} ]]; then
        _TCB_PULL_REMOTE=true
        _TCB_CHOSEN_TAG=${_TCB_USER_TAG}
    fi

    return 0
}

_tcb_pull_if_needed() {
    echo -e "Setting up TorizonCore Builder with version ${_TCB_CHOSEN_TAG}.\n"

    if [[ ${_TCB_PULL_REMOTE} == true ]]; then
        echo -e "Pulling TorizonCore Builder..."
        if docker pull torizon/torizoncore-builder:"${_TCB_CHOSEN_TAG}"; then
            echo -e "Done!\n"
        else
            echo "Error: could not pull TorizonCore Builder from Docker Hub!"
            _tcb_cleanup
            return 1
        fi
    fi

    return 0
}

_tcb_load_completion_if_latest() {
    if [[ "${_TCB_CHOSEN_TAG}" == "${_TCB_LATEST_REMOTE}" ]]; then
        if wget -q https://raw.githubusercontent.com/toradex/tcb-env-setup/master/torizoncore-builder-completion.bash -O ./torizoncore-builder-completion.bash.tmp 2>/dev/null; then
            source ./torizoncore-builder-completion.bash.tmp 2>/dev/null && rm -rf torizoncore-builder-completion.bash.tmp
        fi
    fi
}

_tcb_dynamic_params() {
    local cont_name="tcb_$(date +%s)"
    echo "-e TCB_CONTAINER_NAME=${cont_name} --name ${cont_name}"
}

_tcb_define_alias() {
    export -f _tcb_dynamic_params
    alias torizoncore-builder='docker run --rm '"${_TCB_INTERACTIVE_FLAGS}"' '"${_TCB_VOLUMES}"'-v "$(pwd)":/workdir -v '"${_TCB_STORAGE}"':/storage -v /var/run/docker.sock:/var/run/docker.sock'"${_TCB_NETWORK}"'$(_tcb_dynamic_params) '"${_TCB_DOCKER_EXTRA}"' torizon/torizoncore-builder:'"${_TCB_CHOSEN_TAG}"
}

_tcb_print_final_messages() {
    local storage_desc="${_TCB_STORAGE}"

    if [[ ${storage_desc} =~ ^[a-zA-Z][a-zA-Z0-9_.-]*$ ]]; then
        storage_desc="Docker volume named '${storage_desc}'"
    fi

    cat <<EOF
Setup complete. TorizonCore Builder is ready.

== Storage
   Internal status and image customizations will be stored in ${storage_desc}.

== Workspace Scope
   - Only files and directories in the current working directory or below are
     visible to the tool.
   - Absolute symlinks and relative symlinks pointing outside these directories
     are also not visible/accessible to the tool.

== Help
   - Run: torizoncore-builder -h
   - Docs: https://developer.toradex.com/knowledge-base/torizoncore-builder-tool
EOF
}

_tcb_main() {
    _tcb_check_sourced
    _tcb_cleanup
    _tcb_detect_platform
    _tcb_detect_tty
    _tcb_init_defaults

    if ! _tcb_parse_args "$@"; then
        _tcb_teardown
        return
    fi

    if [[ ${_TCB_AUTO_MODE} != "local" ]]; then
        _tcb_set_script_path
        _tcb_check_updated "${_TCB_SCRIPT_PATH}"
    fi

    if ! _tcb_validate_inputs "$@"; then
        _tcb_teardown
        return
    fi
    _tcb_load_tags
    if ! _tcb_choose_tag; then
        _tcb_teardown
        return
    fi
    if ! _tcb_pull_if_needed; then
        _tcb_teardown
        return
    fi
    _tcb_load_completion_if_latest
    _tcb_define_alias
    _tcb_print_final_messages

    _tcb_cleanup
    _tcb_teardown
    unset -f _tcb_cleanup 2>/dev/null
    unset -f _tcb_teardown 2>/dev/null
}

_tcb_main "$@"
