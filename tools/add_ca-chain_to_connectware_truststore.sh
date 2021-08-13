#!/usr/bin/env bash
#
# Deploys additional ca chain certificates to a local Connectware instance.
#
# Usage:
# - Start this script
# - No restart required
#
# Review:
# - docker exec -it connectware_connectware_1 cat /connectware_certs/cybus_ca.crt
#
# Replace:
# - docker exec -i connectware_connectware_1 sh -c 'cat > /connectware_certs/cybus_ca.crt' < cybus_ca.crt
#
# Append:
# - docker exec -i connectware_connectware_1 sh -c 'cat >> /connectware_certs/cybus_ca.crt' < ca-chain.crt
#
CERT_PATH=${1:-ca-chain.crt}

CERT_DEPLOYMENT_CONTAINER=${2:-connectware_connectware_1}

CONTAINER_PATH="$CERT_DEPLOYMENT_CONTAINER:/connectware_certs/"

echo "append ca chain to existing cybus truststore in connectware target container..."

docker exec -i connectware_connectware_1 sh -c 'cat >> /connectware_certs/cybus_ca.crt' < $CERT_PATH
