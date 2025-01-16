#!/bin/bash

CONFIG_FILE="/home/khara/Documents/Proxiongest/servo.cfg"
# Initialisation
function load_config() {
    base_url=$(awk -F "=" '/^base_url/ {print $2}' "$CONFIG_FILE" | xargs)
    shared_url=$(awk -F "=" '/^shared_url/ {print $2}' "$CONFIG_FILE" | xargs)
    fqdn=$(awk -F "=" '/^fqdn/ {print $2}' "$CONFIG_FILE" | xargs)
    content_type=$(awk -F "=" '/^content_type/ {print $2}' "$CONFIG_FILE" | xargs)
    username=$(awk -F "=" '/^username/ {print $2}' "$CONFIG_FILE" | xargs)
    password=$(awk -F "=" '/^password/ {print $2}' "$CONFIG_FILE" | xargs)
    list_shared=$(awk -F "=" '/^list_shared/ {print $2}' "$CONFIG_FILE" | xargs)
    if [[ -z "$base_url" || -z "$username" || -z "$password" ]]; then
        echo "Error: Missing required configuration parameters."
        exit 1
    fi
}

function get_action_url() {
    local action=$(printf '%q' "$1")
    local param1=$(printf '%q' "$2")
    local param2=$(printf '%q' "$3")

    action_path=$(awk -F "=" -v action="$action" '/^\[actions\]/ {found=1} found && $1~action {print $2; exit}' "$CONFIG_FILE" | xargs)

    if [[ -z "$action_path" ]]; then
        echo "Error: Action '$action' not found in configuration."
        exit 1
    fi

    action_path=${action_path//\{fqdn\}/$fqdn}
    action_path=${action_path//\{param1\}/$param1}
    action_path=${action_path//\{param2\}/$param2}

    echo "$action_path"
}

function replace_x_in_json() {
    if [[ $1 = "generate" ]]; then
        name_tmp="tmp$(date +%s).json"
        cp "/home/khara/Documents/Proxiongest/data.json" "/home/khara/Documents/Proxiongest/$name_tmp"
        local file="/home/khara/Documents/Proxiongest/$name_tmp"
        local arg1=$(search_pos)
        local arg2=$(user_creator)
        local arg3=$(mdp_creator)
        local arg4=$(search_port)
        local arg5=$(date -d "+1 month" +%s%3N)
        if [[ $2 = "meta" ]]; then
            arg6=$(cat /home/khara/Documents/Proxiongest/whitelist/meta)
        elif [[ $2 = "x" ]]; then
            arg6=$(cat /home/khara/Documents/Proxiongest/whitelist/x)
        elif [[ $2 = "google" ]]; then
            arg6=$(cat /home/khara/Documents/Proxionge46.101.83.106st/whitelist/google)
        fi
        sed -i "2s/x/${arg1}/" "$file"
        sed -i "3s/x/${arg1}/" "$file"
        sed -i "4s/x/${arg1}/" "$file"
        sed -i "5s/x/${arg1}/" "$file"
        sed -i "11s/x/${arg2}/" "$file"
        sed -i "11s/x/${arg3}/" "$file"
        sed -i "20s/x/${arg4}/" "$file"
        sed -i "21s/y/${arg5}/" "$file"
        sed -i "22s/x/${arg6}/" "$file"
    elif [[ $1 = "delete" ]]; then
        name_tmp="tmp$(date +%s).json"
        cp "/home/khara/Documents/Proxiongest/delete.json" "/home/khara/Documents/Proxiongest/$name_tmp"
        local file="/home/khara/Documents/Proxiongest/$name_tmp"
        local arg1=$2

        sed -i "1s/x/${arg1}/" "$file"
    fi
}


function search_pos() {
    all_pos=$(curl -s -u \"$username:$password\" $shared_url/$list_shared | jq -j '[.data[].position] | join(" ")')
    declare -A pos_count
    for pos in $all_pos; do
        ((pos_count[$pos]++))
    done
    for pos in "${!pos_count[@]}"; do
        if [[ ${pos_count[$pos]} -lt 3 ]]; then
            echo "$pos"
            return
        fi
    done
    max_pos=$(echo "${!pos_count[@]}" | tr ' ' '\n' | sort -n | tail -1)
    echo $((max_pos + 1))
}

function search_port() {
    all_ports=$(curl -s -u \"$username:$password\" $shared_url/$list_shared | jq -j '[.data[].shared_port] | join(" ")')
    used_ports=($(echo "$all_ports" | tr ' ' '\n' | sort -n))
    local start_port=20001
    for ((port=start_port; ; port++)); do
        if ! [[ " ${used_ports[*]} " =~ " $port " ]]; then
            echo "$port"
            return
        fi
    done
}

function user_creator() {
    local length=$((RANDOM % 5 + 8))
    tr -dc 'a-zA-Z0-9' </dev/urandom | head -c "$length"
}

function mdp_creator() {
    local length=$((RANDOM % 5 + 8))
    tr -dc 'a-zA-Z0-9' </dev/urandom | head -c "$length"
}

function beautyfier() {
    if echo "$1" | jq . > /dev/null 2>&1; then
        echo "$1" | jq .
    else
        echo "$1"
    fi
}


function make_action() {
    load_config

    local action=$(printf '%q' "$1")
    local platform=$(printf '%q' "$2")
    local param1=$(printf '%q' "$3")
    local param2=$(printf '%q' "$4")

    local action_url
    action_url=$(get_action_url "$action" "$param1" "$param2")

    if [[ -z "$action_url" ]]; then
        echo "Error: Invalid action '$action'."
        return 1
    fi

    local full_command
    if [[ "$action" == "generate_shared" ]]; then
        if [[ $platform != "meta" || $platform != "x" || $platform != "google" || $platform != "" ]]; then
            replace_x_in_json generate $platform
            data_raw="/home/khara/Documents/Proxiongest/$name_tmp"
            full_command="curl -s -u \"$username:$password\" -X POST \"$shared_url/$action_url\" \\
                -H \"Accept: $content_type\" \\
                -H \"Content-Type: $content_type\" \\
                --data @$data_raw"
        else
            exit 1
        fi
    elif [[ "$action" == "delete_shared" ]]; then
        replace_x_in_json delete $platform
        data_raw="/home/khara/Documents/Proxiongest/$name_tmp"
        full_command="curl -s -u \"$username:$password\" -X POST \\
            -H \"Content-Type: $content_type\" \\
            \"$shared_url/$action_url\" --data @$data_raw"
    elif [[ "$action" == "list_shared" ]]; then
        full_command="curl -s -u \"$username:$password\" $shared_url/$list_shared"
    else
        full_command="curl -s -u \"$username:$password\" -X GET \\
            -H \"Content-Type: $content_type\" \\
            \"$base_url/$action_url\""
    fi

    response=$(eval "$full_command")

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to execute request."
        return 1
    fi
    echo "$response"
    echo "NAME_TMP=$name_tmp"
}

if [[ "$#" -lt 1 || "$#" -gt 4 ]]; then
    echo "Error: You need between 1 to 4 arguments."
    echo "Usage: servo.sh <action> [platform] [param1] [param2]"
    echo "Type './servo.sh help' for more details."
    exit 1
fi

if [[ "$1" == "help" ]]; then
    echo "Usage: servo.sh <action> [platform] [param1] [param2]"
    echo
    echo "Available actions:"
    awk -F "=" '/^\[actions\]/ {found=1} found && !/^\[.*\]/ {print "  "$1}' "$CONFIG_FILE"
    echo
    exit 0
fi


raw_output=$(make_action "$@")

json_part=$(echo "$raw_output" | sed -n '/^NAME_TMP=/q;p')
tmp_part=$(echo "$raw_output" | sed -n 's/^NAME_TMP=//p')
if [[ $? -eq 0 ]]; then
    beautyfier "$json_part"
    echo "/home/khara/Documents/Proxiongest/$tmp_part"
    if [[ -f "/home/khara/Documents/Proxiongest/$tmp_part" ]]; then
        echo $tmp_part
        rm "/home/khara/Documents/Proxiongest/$tmp_part"
    fi
else
    echo "Error: Action failed."
    exit 1
fi
