#!/bin/bash

if [[ "$#" -lt 1 || "$#" -gt 3 ]]; then
    echo "Error : To launch it, you need between 1 to 3 args."
    echo "Usage : servo.sh <action> [param1] [param2]."
    echo "Type './servo.sh help' if you need more help" 
    exit 1
fi

if [[ "$1" == "help" ]]; then
    echo "Usage: servo.sh <action> [param1] [param2]"
    echo
    echo "Available actions:"
    echo "  list_all              - List all available items."
    echo "  rotation_ip_proxy     - Rotate the IP of a specific proxy."
    echo "  rotation_ip_position  - Rotate the IP of a specific position."
    echo "  status_proxy          - Get the status of a specific proxy."
    echo "  status_position       - Get the status of a specific position."
    echo "  reboot_proxy          - Reboot a specific proxy."
    echo "  reboot_position       - Reboot a specific position."
    echo "  list_shared           - List all shared proxies."
    echo "  generate_shared       - Generate shared proxies."
    echo "  delete_shared         - Delete shared proxies."
    echo "  reset_data_counter    - Reset the data counter for proxies."
    echo
    echo "Examples:"
    echo "  servo.sh list_all"
    echo "  servo.sh rotation_ip_proxy <proxy_id>"
    echo "  servo.sh list_shared 1 10"
    echo
    exit 0
fi

command_curl_get="curl -s -X GET -H"
command_curl_post="curl -s -X POST"
type_content="Content-Type: application/json"
base_url="http://lte.ionproxy.com/api/v1"
shared_url="http://lte.ionproxy.com"
fqdn="lte.ionproxy.com"
actions=("list_all" "rotation_ip_proxy" "rotation_ip_position" "status_proxy" "status_position" "reboot_proxy" "reboot_position" "list_shared" "generate_shared" "delete_shared" "reset_data_counter")

real_actions_v1=("info_list" "rotate_ip/proxy/$fqdn:$2" "rotate_ip/position/$2" "status/proxy/$fqdn:$2" "status/position/$2" "reboot/proxy/$fqdn:$2" "reboot/position/$2")
real_actions=("selling/shared_proxies?page=$2&limit=$3" "selling/generate" "selling/bulk_delete" "selling/reset_data_counter")

function make_action() {
    local action=$1
    local index=0

    for valid_action in "${actions[@]}"; do
        if [[ "$action" == "$valid_action" ]]; then
            case $index in
                [0-6])
                    full_url="$base_url/${real_actions_v1[$index]}"
                    full_command="$command_curl_get \"$type_content\" \"$full_url\""
                    to_return=$(eval "$full_command")
                    ;;
                7)
                    full_url="$shared_url/${real_actions[$index-7]}"
                    to_return=$(curl -s "$full_url")
                    ;;
                [8-10])
                    full_url="$shared_url/${real_actions[$index-7]}"
                    full_command="$command_curl_post \"$full_url\" -H \"$type_content\" -d \"$2\""
                    to_return=$(eval "$full_command")
                    ;;
                *)
                    echo "Error: Invalid action '$action'."
                    return 1
                    ;;
            esac
            echo "$to_return"
            return 0
        fi
        ((index++))
    done

    echo "Error: Invalid action '$action'."
    return 1
}

function beautyfier() {
    if echo "$1" | jq . > /dev/null 2>&1; then
        echo "$1" | jq .
    else
        echo "Error: Invalid JSON response."
    fi
}

if ! got=$(make_action "$@"); then
    echo "$got"
    exit 1
fi

beautyfier "$got"
