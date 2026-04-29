#!/usr/bin/env bash
# config.sh — shared helper: read credentials from local SQLite vault
# Source this file in other scripts: source "$(dirname "$0")/config.sh"
#
# DB location: ~/.web-deploy/config.db
# Never hardcode credentials — always read from here.

DB_DIR="${HOME}/.web-deploy"
DB_PATH="${DB_DIR}/config.db"

# Ensure DB and tables exist
_init_db() {
  mkdir -p "$DB_DIR"
  chmod 700 "$DB_DIR"
  sqlite3 "$DB_PATH" <<'SQL'
CREATE TABLE IF NOT EXISTS credentials (
  id      INTEGER PRIMARY KEY AUTOINCREMENT,
  service TEXT NOT NULL,
  key     TEXT NOT NULL,
  value   TEXT NOT NULL,
  UNIQUE(service, key)
);

CREATE TABLE IF NOT EXISTS servers (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  forge_server_id TEXT,
  name            TEXT,
  ip_address      TEXT,
  provider        TEXT,
  status          TEXT DEFAULT 'unknown',
  created_at      TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS domains (
  id                   INTEGER PRIMARY KEY AUTOINCREMENT,
  domain               TEXT UNIQUE,
  cloudflare_zone_id   TEXT,
  cloudflare_account_id TEXT,
  registered_at        TEXT DEFAULT (datetime('now'))
);
SQL
  chmod 600 "$DB_PATH"
}

# Get a credential value
# Usage: get_cred <service> <key>
# Example: FORGE_TOKEN=$(get_cred forge api_token)
get_cred() {
  local service="$1"
  local key="$2"
  sqlite3 "$DB_PATH" "SELECT value FROM credentials WHERE service='$service' AND key='$key' LIMIT 1;"
}

# Set a credential value
# Usage: set_cred <service> <key> <value>
set_cred() {
  local service="$1"
  local key="$2"
  local value="$3"
  sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO credentials (service, key, value) VALUES ('$service', '$key', '$value');"
}

# Check a required credential exists, exit if not
# Usage: require_cred <service> <key> <hint>
require_cred() {
  local service="$1"
  local key="$2"
  local hint="$3"
  local val
  val=$(get_cred "$service" "$key")
  if [ -z "$val" ]; then
    echo "❌ Missing credential: $service.$key"
    echo "   Run: bash scripts/setup.sh to configure"
    [ -n "$hint" ] && echo "   $hint"
    exit 1
  fi
  echo "$val"
}

# Save a server record
save_server() {
  local forge_id="$1" name="$2" ip="$3" provider="$4" status="$5"
  sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO servers (forge_server_id, name, ip_address, provider, status) VALUES ('$forge_id','$name','$ip','$provider','$status');"
}

# Save a domain record
save_domain() {
  local domain="$1" zone_id="$2" account_id="$3"
  sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO domains (domain, cloudflare_zone_id, cloudflare_account_id) VALUES ('$domain','$zone_id','$account_id');"
}

# Get domain zone_id
get_zone_id() {
  local domain="$1"
  sqlite3 "$DB_PATH" "SELECT cloudflare_zone_id FROM domains WHERE domain='$domain' LIMIT 1;"
}

# Init on source
_init_db
