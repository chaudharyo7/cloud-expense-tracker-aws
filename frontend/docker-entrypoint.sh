#!/bin/sh
set -e

INSTANCE_ID="${EC2_INSTANCE_ID}"
PUBLIC_IP="${EC2_PUBLIC_IP}"

# Fallback: if not supplied by env vars, try IMDSv2 directly
if [ -z "$INSTANCE_ID" ] || [ -z "$PUBLIC_IP" ]; then
  TOKEN=$(curl -s -f -m 2 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null || true)
  if [ -n "$TOKEN" ]; then
    [ -z "$INSTANCE_ID" ] && INSTANCE_ID=$(curl -s -f -m 2 -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || true)
    [ -z "$PUBLIC_IP" ] && PUBLIC_IP=$(curl -s -f -m 2 -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || true)
  fi
fi

# Fallback default values for local development
INSTANCE_ID="${INSTANCE_ID:-local-dev}"
PUBLIC_IP="${PUBLIC_IP:-127.0.0.1}"
cat <<EOF > /usr/share/nginx/html/instance-info.json
{
  "public_ip": "$PUBLIC_IP"
}
EOF

exec "$@"
