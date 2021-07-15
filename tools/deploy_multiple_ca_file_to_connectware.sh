#!/usr/bin/env bash
#
# Deploys a cybus_ca.crt file to a local Connectware instance.
#
# Usage:
# - Start this script
# - Restart the connectware_connectware_1 container
# - Wait for 20-40 seconds
#
CERT_PATH=${1:-cybus_ca_multiple_root.crt}

CERT_DEPLOYMENT_CONTAINER=${2:-connectware_connectware_1}

CONTAINER_PATH="$CERT_DEPLOYMENT_CONTAINER:/connectware_certs/"

echo "copying cybus_ca.crt to connectware target container..."
docker cp -L $CERT_PATH $CONTAINER_PATH/cybus_ca.crt

echo "restarting connectware target container"
docker restart $CERT_DEPLOYMENT_CONTAINER

echo "certificate deployment done."
