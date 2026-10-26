#!/bin/sh
# Runs as the server user before Paper loads the plugin configuration.
set -eu

export CFG_CLAIM_BLOCK_PRICE=${CFG_CLAIM_BLOCK_PRICE:-10.0}
# GriefPrevention 16.18.7 uses DataStore.configFilePath, NOT getDataFolder().
# Its configuration lives next to ClaimData and PlayerData in GriefPreventionData.
export CFG_CLAIM_CONFIG_FILE="${SERVER_DIR:-/data}/plugins/GriefPreventionData/config.yml"
patch_file="$(dirname "$0")/griefprevention-economy.json"

# Reject invalid prices before touching the existing configuration.
if ! awk -v price="$CFG_CLAIM_BLOCK_PRICE" 'BEGIN {
    exit !(price ~ /^[0-9]+([.][0-9]+)?$/ && price > 0)
}'; then
    printf 'CFG_CLAIM_BLOCK_PRICE must be a positive number (e.g. 10.0).\n' >&2
    exit 1
fi

mkdir -p "$(dirname "$CFG_CLAIM_CONFIG_FILE")"
if [ ! -e "$CFG_CLAIM_CONFIG_FILE" ]; then
    # GriefPrevention fills in its remaining defaults on the first start.
    printf 'GriefPrevention:\n  Economy: {}\n' > "$CFG_CLAIM_CONFIG_FILE"
elif [ ! -e "$CFG_CLAIM_CONFIG_FILE.before-claim-shop" ]; then
    cp -p "$CFG_CLAIM_CONFIG_FILE" "$CFG_CLAIM_CONFIG_FILE.before-claim-shop"
fi

# Update only the purchase price; preserve claims, player data and other options.
mc-image-helper patch --patch-env-prefix=CFG_ "$patch_file"
configured_price=$(mc-image-helper yaml-path --file="$CFG_CLAIM_CONFIG_FILE" '$.GriefPrevention.Economy.ClaimBlocksPurchaseCost')
if ! awk -v actual="$configured_price" -v expected="$CFG_CLAIM_BLOCK_PRICE" 'BEGIN {
    exit !(actual ~ /^[0-9]+([.][0-9]+)?$/ && actual + 0 == expected + 0)
}'; then
    printf '[claims] Failed to verify the purchase price in %s.\n' "$CFG_CLAIM_CONFIG_FILE" >&2
    exit 1
fi
printf '[claims] Saved ClaimBlocksPurchaseCost=%s in %s; Paper will load this configuration on startup.\n' "$configured_price" "$CFG_CLAIM_CONFIG_FILE"
