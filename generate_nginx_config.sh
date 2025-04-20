#!/bin/bash
set -e

APPS_JSON_FILE="/etc/nginx/apps.json"
NGINX_CONFIG_FILE="/etc/nginx/nginx.conf"

# verify that jq is installed
# jq is used to parse JSON files
if ! command -v jq &> /dev/null; then
    echo "jq is not installed. Please add it to the Docker image."
    exit 1
fi

# Initial header for the NGINX configuration
# This is a basic NGINX configuration template
NGINX_CONFIG=$(cat <<'EOF'
events {}

http {
  include       mime.types;
  default_type  application/octet-stream;
  sendfile      on;

EOF
)

# Add each app configuration
# The script reads the JSON file line by line and generates the NGINX configuration
while IFS= read -r app_json; do
  domains=$(echo "$app_json" | jq -r '.domains | join(" ")')
  service=$(echo "$app_json" | jq -r '.service')
  port=$(echo "$app_json" | jq -r '.port')
  certsPath=$(echo "$app_json" | jq -r '.certsPath')

  # readable comment
  comment="  ########################################################################
  # ${service} - on ${domains}
  ########################################################################
"

  # Redirect HTTP -> HTTPS
  http_block="  server {
    listen 80;
    server_name ${domains};
    return 301 https://\$host\$request_uri;
  }
"

  # HTTPS server block: handles secure connections
  # Uses SSL certificates specified in the JSON file
  # With Docker's resolver, Nginx won't crash when the service is unavailable
  https_block="  server {
    listen 443 ssl;
    server_name ${domains};

    ssl_certificate ${certsPath}/cert.pem;
    ssl_certificate_key ${certsPath}/privkey.pem;
    ssl_trusted_certificate ${certsPath}/chain.pem;

    resolver 127.0.0.11;

    location / {
      set \$upstream_url http://${service}:${port};
      proxy_pass \$upstream_url;
      proxy_set_header Host \$host;
      proxy_set_header X-Real-IP \$remote_addr;
      proxy_set_header X-Forwarded-Proto https;
    }
  }
"

  # Append the blocks to the NGINX config
  NGINX_CONFIG="${NGINX_CONFIG}
${comment}
${http_block}
${https_block}
"
done < <(jq -c '.[]' "$APPS_JSON_FILE")

# close the http block
NGINX_CONFIG="${NGINX_CONFIG}
}
"

# write the NGINX config to the file
echo "$NGINX_CONFIG" > "$NGINX_CONFIG_FILE"

# Display the generated configuration for verification
echo "--- NGINX config file successfully created ---" 
cat "$NGINX_CONFIG_FILE"
echo "--- End ---"
