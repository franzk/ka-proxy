FROM nginx:stable-alpine

# Install Bash and jq
RUN apk add --no-cache bash jq

# remove the default Nginx configuration
RUN rm /etc/nginx/conf.d/default.conf

# copy the list of applications data used to generate the Nginx configuration
COPY apps.json /etc/nginx/apps.json

# copy the Nginx configuration generator script to the entrypoint directory
# This script will generate the Nginx configuration based on the apps.json file when Nginx starts
COPY generate_nginx_config.sh /docker-entrypoint.d/
RUN chmod +x /docker-entrypoint.d/generate_nginx_config.sh

CMD ["nginx", "-g", "daemon off;"]