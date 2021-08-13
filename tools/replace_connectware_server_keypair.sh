#!/usr/bin/env bash
#
# Deploys server cert and key to a local Connectware instance.
#
# Usage:
# - Start this script
# - Restart the connectware_connectware_1 container
# - Wait for 20-40 seconds
#
#
CERT_PATH=${1:-certificate.crt}
KEY_PATH=${2:-privateKey.key}

CERT_DEPLOYMENT_CONTAINER=${3:-connectware_connectware_1}

CONTAINER_PATH="$CERT_DEPLOYMENT_CONTAINER:/connectware_certs/"

echo "copying certificate and key to connectware target container..."
docker cp -L $KEY_PATH $CONTAINER_PATH/cybus_server.key
docker cp -L $CERT_PATH $CONTAINER_PATH/cybus_server.crt

echo "restarting connectware target container"
docker restart $CERT_DEPLOYMENT_CONTAINER

echo "certificate deployment done."
