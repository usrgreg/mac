#!/bin/bash
# Usage: sudo ./add_client.sh <client-name>
# Adds a new WireGuard client without disconnecting existing ones

if [ -z "$1" ]; then
    echo "Usage: $0 <client-name>"
    exit 1
fi

CLIENT_NAME="$1"
WG_DIR="/etc/wireguard"
WG_CONF="$WG_DIR/wg0.conf"
SERVER_PUB_IP="74.235.254.20"
SERVER_PORT=51820
VPN_SUBNET="10.0.0"

# --- Find the next unused IP ---
USED_IPS=$(grep -oP '(?<=AllowedIPs = )'"$VPN_SUBNET"'\.\d+' "$WG_CONF" | awk -F. '{print $4}' | sort -n)

NEXT_IP=2  # start from .2 because .1 is server
while echo "$USED_IPS" | grep -q "^$NEXT_IP$"; do
    NEXT_IP=$((NEXT_IP + 1))
done

CLIENT_IP="$VPN_SUBNET.$NEXT_IP"

# --- Generate client keys ---
CLIENT_PRIV=$(wg genkey)
CLIENT_PUB=$(echo "$CLIENT_PRIV" | wg pubkey)

# --- Save client config ---
CLIENT_CONF="$WG_DIR/${CLIENT_NAME}.conf"
cat > "$CLIENT_CONF" <<EOF
[Interface]
PrivateKey = $CLIENT_PRIV
Address = $CLIENT_IP/24
DNS = 1.1.1.1

[Peer]
PublicKey = $(cat "$WG_DIR/server_public.key")
Endpoint = $SERVER_PUB_IP:$SERVER_PORT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

# --- Append to server config (persistent) ---
cat >> "$WG_CONF" <<EOF

# $CLIENT_NAME
[Peer]
PublicKey = $CLIENT_PUB
AllowedIPs = $CLIENT_IP/32
EOF

# --- Add peer live without restart ---
wg set wg0 peer "$CLIENT_PUB" allowed-ips "$CLIENT_IP/32"

# --- Generate QR codes ---
echo "=== QR code for $CLIENT_NAME ==="
qrencode -t ansiutf8 < "$CLIENT_CONF"

qrencode -t png -o "${CLIENT_NAME}.png" < "$CLIENT_CONF"
echo "PNG QR code saved as ${CLIENT_NAME}.png"

echo "✅ Client $CLIENT_NAME added with IP $CLIENT_IP"

cat $CLIENT_CONF
