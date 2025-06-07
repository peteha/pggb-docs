# Telegraf Installation and Registration (CLI Script)

This script sets up Telegraf on a Linux system, configures the InfluxData repository, installs dependencies, pulls a remote utility script, and registers the agent with a remote collector.

## 🧰 Requirements
- Root/sudo access
- Internet access to `repos.influxdata.com` and the `OPS_HOST` endpoint
- curl, jq, gpg, sha256sum

### 1. VCF Operations Collection Proxy and Collector Group

Telegraf requires an additional proxy collector which the Telegraf agents connect to.  The following is a screenshot of the proxy used in the example.

![](images/CleanShot%202025-05-29%20at%2006.42.42@2x.png)<!-- {"width":755} -->

The proxy is added to a collector group.   In my example I am using a non-HA collector group called ‘pggb’.  The following is the screen shot of my example collector group.

Use the IP address of the porxy in the script.

![](images/CleanShot%202025-05-29%20at%2006.46.03@2x.png)<!-- {"width":749} -->

Update the configuration with your environment.

## 📜 Script

```bash
#!/bin/bash

set -e

# === Configuration ===
OPS_USER="admin"
OPS_PASSWORD="PASSWORD123"
OPS_PROXY_IP="10.205.16.57"
OPS_HOST="pgops.pggb.net"
COLLECTION_GROUP="10.205.16.57"

TELEGRAF_BIN="/usr/bin/telegraf"
TELEGRAF_CONFIG_DIR="/etc/telegraf/telegraf.d"
TEMP_DIR="/opt/deploy/temp"
KEY_SHA256="943666881a1b8d9b849b74caebf02d3465d6beb716510d86a39f6c8e8dac7515"

# === Install base packages ===
apt-get update

apt-get install -y unzip coreutils net-tools jq curl gpg

# === Create temp directory ===
mkdir -p "$TEMP_DIR"

# === Add InfluxData repo and key ===
cd "$TEMP_DIR"

curl --silent --location -O https://repos.influxdata.com/influxdata-archive.key

echo "$KEY_SHA256  influxdata-archive.key" | sha256sum -c -

cat influxdata-archive.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/influxdata-archive.gpg > /dev/null

echo "deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive.gpg] https://repos.influxdata.com/debian stable main" \
  | tee /etc/apt/sources.list.d/influxdata.list

# === Install Telegraf ===
apt-get update

apt-get install -y telegraf

# === Create config directory ===
mkdir -p "$TELEGRAF_CONFIG_DIR"

# === Download helper script ===
curl --insecure -L -o "$TEMP_DIR/telegraf-utils.sh" "https://${OPS_PROXY_IP}/downloads/salt/telegraf-utils.sh"

chmod +x "$TEMP_DIR/telegraf-utils.sh"

# === Acquire auth token ===
curl -X POST "https://${OPS_HOST}/suite-api/api/auth/token/acquire?_no_links=true" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -d "{ \"username\": \"${OPS_USER}\", \"password\": \"${OPS_PASSWORD}\" }" \
  --insecure | jq -r .token > "$TEMP_DIR/auth_token.txt"

# === Verify token exists ===
if [[ ! -f "$TEMP_DIR/auth_token.txt" ]]; then
  echo "Auth token not found, exiting"
  exit 1
fi

# === Register Telegraf ===
TOKEN=$(cat "$TEMP_DIR/auth_token.txt")

"$TEMP_DIR/telegraf-utils.sh" opensource \
  -c "$COLLECTION_GROUP" \
  -t "$TOKEN" \
  -d "$TELEGRAF_CONFIG_DIR" \
  -e "$TELEGRAF_BIN" \
  -v "$OPS_HOST"

# === Fix permissions ===
chmod 644 "$TELEGRAF_CONFIG_DIR/cert.pem"
chmod 644 "$TELEGRAF_CONFIG_DIR/key.pem"

# === Restart Telegraf ===
systemctl restart telegraf

systemctl enable telegraf

echo "✅ Telegraf installed and registered successfully with your.ops.host"
```