#!/bin/bash

CONFIG_FILE="/home/khara/Documents/Proxiongest/servo.cfg"

# Vérifier l'existence du fichier de configuration
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration file '$CONFIG_FILE' not found."
    exit 1
fi

# Charger les paramètres depuis le fichier de configuration
function load_config() {
    base_url=$(awk -F "=" '/^base_url/ {print $2}' "$CONFIG_FILE" | xargs)
    shared_url=$(awk -F "=" '/^shared_url/ {print $2}' "$CONFIG_FILE" | xargs)
    fqdn=$(awk -F "=" '/^fqdn/ {print $2}' "$CONFIG_FILE" | xargs)
    content_type=$(awk -F "=" '/^content_type/ {print $2}' "$CONFIG_FILE" | xargs)
    username=$(awk -F "=" '/^username/ {print $2}' "$CONFIG_FILE" | xargs)
    password=$(awk -F "=" '/^password/ {print $2}' "$CONFIG_FILE" | xargs)
    limit_prox=$(awk -F "=" '/^limit_shared/ {print $2}' "$CONFIG_FILE" | xargs)
    # Vérifier que les variables essentielles sont chargées
    if [[ -z "$base_url" || -z "$username" || -z "$password" ]]; then
        echo "Error: Missing required configuration parameters."
        exit 1
    fi
}

# Obtenir l'URL pour une action spécifique
function get_action_url() {
    local action=$1
    local param1=$2
    local param2=$3

    action_path=$(awk -F "=" -v action="$action" '/^\[actions\]/ {found=1} found && $1~action {print $2; exit}' "$CONFIG_FILE" | xargs)

    if [[ -z "$action_path" ]]; then
        echo "Error: Action '$action' not found in configuration."
        exit 1
    fi

    # Remplacer les variables dans le chemin
    action_path=${action_path//\{fqdn\}/$fqdn}
    action_path=${action_path//\{param1\}/$param1}
    action_path=${action_path//\{param2\}/$param2}

    echo "$action_path"
}

# Fonction principale pour exécuter une action
function make_action() {
    load_config

    local action=$1
    local param1=$2
    local param2=$3

    local action_url
    action_url=$(get_action_url "$action" "$param1" "$param2")
    echo $action $param1 $param2
    if [[ -z "$action_url" ]]; then
        echo "Error: Invalid action '$action'."
        return 1
    fi

    # Construire la commande avec Basic Auth
    local full_command
    if [[ "$action" == "generate_shared" || "$action" == "delete_shared" || "$action" == "reset_data_counter" ]]; then
        full_command="curl -s -u $username:$password -X POST \"$shared_url/$action_url\" -H \"Content-Type: $content_type\""
    else
        full_command="curl -u $username:$password -X GET -H \"Content-Type: $content_type\" \"$base_url/$action_url\""
    else if [[ "$action" == "list_shared" ]]; then
        full_command="curl -u $username:$password \"$base_url/$action_url\""
    fi
    echo $full_command
    response=$(eval "$full_command")

    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to execute request."
        return 1
    fi

    echo "$response"
}

# Beautifier les réponses JSON
function beautyfier() {
    if echo "$1" | jq . > /dev/null 2>&1; then
        echo "$1" | jq .
    else
        echo "$1"
    fi
}

# Vérification des arguments et exécution
if [[ "$#" -lt 1 || "$#" -gt 3 ]]; then
    echo "Error: You need between 1 to 3 arguments."
    echo "Usage: servo.sh <action> [param1] [param2]"
    echo "Type './servo.sh help' for more details."
    exit 1
fi

if [[ "$1" == "help" ]]; then
    echo "Usage: servo.sh <action> [param1] [param2]"
    echo
    echo "Available actions:"
    awk -F "=" '/^\[actions\]/ {found=1} found && !/^\[.*\]/ {print "  "$1}' "$CONFIG_FILE"
    echo
    exit 0
fi


# Exécuter l'action demandée
result=$(make_action "$@")
if [[ $? -eq 0 ]]; then
    beautyfier "$result"
else
    echo "Error: Action failed."
    exit 1
fi