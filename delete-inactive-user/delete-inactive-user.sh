#!/bin/bash
set -euo pipefail

DD_API_KEY="${DD_API_KEY:-}"
DD_APP_KEY="${DD_APP_KEY:-}"
SITE="${SITE:-datadoghq.com}"

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

# Get users list with pagination
get_users() {
  local page=0
  local size=50
  : > users_raw.txt

  while :; do
    resp="$(
      curl -sS --compressed -G "https://api.${SITE}/api/v2/users" \
        -H "Accept: application/json" \
        -H "DD-API-KEY: ${DD_API_KEY}" \
        -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" \
        --data-urlencode "page[size]=${size}" \
        --data-urlencode "page[number]=${page}"
    )"

    # Write user ID
    if ! jq -e '.data | length > 0' >/dev/null <<<"$resp"; then
      break
    fi
    jq -r '.data[].id' <<<"$resp" >> users_raw.txt
    page=$((page + 1))
  done

  sort -u users_raw.txt
}

# Deactivate users (disable)
delete_users() {
  local user_id="${1}"
  curl -sS -X DELETE "https://api.${SITE}/api/v2/users/${user_id}" \
    -H "DD-API-KEY: ${DD_API_KEY}" \
    -H "DD-APPLICATION-KEY: ${DD_APP_KEY}"
}

# Remove temp files
cleanup() {
  rm -f audit_users_raw.txt users_raw.txt audit_users.txt users.txt
}

main() {

  get_users_audit_events > audit_users.txt
  get_users > users.txt

  # Get users that are not in audit_users.txt 
  list_users=$(comm -23 users.txt audit_users.txt)

  # Deactivate users from list
  for user in $list_users; do
    delete_users "$user"
  done

  cleanup
}

main "$@"
