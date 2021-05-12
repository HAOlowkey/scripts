#!/bin/bash

set -o nounset
# ##############################################################################
# Globals, settings
# ##############################################################################
POSIXLY_CORRECT=1
export POSIXLY_CORRECT
LANG=C
FILE_NAME="test"

INPUT="$1"
# ##############################################################################
# common function package
# ##############################################################################
die () {
    local status="${1}"
    shift
    local function_name="${1}"
    shift
    error "${function_name}" "$*"
    exit "$status"
}

error () {
    local function_name="${1}"
    shift
    local timestamp
    timestamp="$( date +"%Y-%m-%d %T %N" )"

    echo "[${timestamp}] ERR[${function_name}]: $* ;" | tee -a "${LOG_FILE}"
}
info () {
    local function_name="${1}"
    shift
    local timestamp
    timestamp="$( date +"%Y-%m-%d %T %N" )"

    echo "[${timestamp}] INFO[${function_name}]: $* ;" | tee -a "${LOG_FILE}"
}

installed () {
    command -v "$1" >/dev/null 2>&1
}

check_value_is_exist () {
    local key="${1}"
    local input="${2}"
    local output

    output="$( jq --raw-output -c "${key}" 2> /dev/null <<< "${input}" )"

    [[ "${output}" != "null" ]] || return 2
}

get_value_not_null () {
    local func_name="${FILE_NAME}.get_value_not_null"

    local key="${1}"
    local input="${2}"

    local output

    check_value_is_exist "${key}" "${input}" || {
        error "${func_name}" "check value is not exist"
        return 2
    }

    output="$( jq --raw-output -c "${key}" <<< "${input}" 2> /dev/null )"

    [[ -n "${output}" ]] || {
        error "${func_name}" "the length of value is zero"
        return 2
    }

    [[ "${output}" != "null" ]] || {
        error "${func_name}" "value equal to \"null\""
        return 2
    }

    echo "${output}"
}
# ##############################################################################
# The main() function is called at the action function.
# ##############################################################################
main(){
    local func_name="${FILE_NAME}.main"

    installed jq || die 50 "${func_name}" "not found jq"

    while read -r line ; do

        echo "===================================================================="
        local datapoints
        datapoints="$( get_value_not_null ".dataResult.dataPoints" "${line}" )"

        while read -r key; do
            local service_output
            service_output="$( jq .'["'${key}'"]' <<< "${datapoints}" )"
            local tmp_output
            tmp_output="$( get_value_not_null ".dataResult.entities" "${line}")"
            local entities_output
            entities_output="$( jq -r .'["'${key}'"]' <<< "${tmp_output}" )"
            local i=0
            while [[ $( jq .[${i}] <<< "${service_output}" ) != "null" ]]; do
                local timestamp
                timestamp="$( jq ".[${i}][0]" <<< "${service_output}" )"
                local value
                value="$( jq ".[${i}][1]" <<< "${service_output}" )"
                echo "${timestamp} ${key} ${value} ${entities_output}"
                (( i++ ))
            done
        done <<< "$( jq -r 'keys[]' <<< "${datapoints}" )"
    done < "${INPUT}"
}
main "${@:-""}"
