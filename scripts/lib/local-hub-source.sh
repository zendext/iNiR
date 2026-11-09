# Prefer the built downstream families while keeping the official Hub catalogue.
inir_local_hub_source() {
    local index="$1/local-families/dist/index.json" url
    [[ -z "${INIR_HUB_SOURCES:-}" && -f "$index" ]] || return 0
    url="$(jq -nr --arg path "$index" '$path | @uri | gsub("%2F"; "/")')" || return 1
    export INIR_HUB_SOURCES="file://$url https://inir.space/hub/index.json"
}
