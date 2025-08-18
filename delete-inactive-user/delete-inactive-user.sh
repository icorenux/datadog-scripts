#!/bin/bash

set -euo pipefail

DD_API_KEY=""
DD_APP_KEY=""
SITE="datadoghq.com"

# Get users from Audit Events
get_users_audit_events() {
    curl -sS --compressed -G "https://api.${SITE}/api/v2/audit/events" \
        -H "Accept: application/json" \
        -H "DD-API-KEY: ${DD_API_KEY}" \
        -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" \
        --data-urlencode 'filter[from]=now-90d' \
        --data-urlencode 'filter[to]=now' \
    | jq -r '.data[].attributes.attributes.usr.uuid' | sort -u
}

# Get users from the list of the existing Users
get_users() {
    curl -sS --compressed -G "https://api.${SITE}/api/v2/users" \
        -H "Accept: application/json" \
        -H "DD-API-KEY: ${DD_API_KEY}" \
        -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" \
    | jq -r '.data[].id' | sort -u
}

# Deactivate users
delete_users() {
    local user_id="${1}"
    curl -X DELETE "https://api.datadoghq.com/api/v2/users/${user_id}" \
        -H "DD-API-KEY: ${DD_API_KEY}" \
        -H "DD-APPLICATION-KEY: ${DD_APP_KEY}"
}

# Remove temp files
cleanup() {
    rm -f audit_users.txt users.txt
}

main() {
    get_users_audit_events > audit_users.txt
    get_users > users.txt

    # Compare the two lists to find users not in audit events 
    list_users=$(comm -23 users.txt audit_users.txt) 

    # Deactivate users from the list  
    for user in $list_users; do 
        delete_users $user
    done

    # Remove temporary files  
    cleanup
}

main "$@"

