#!/usr/bin/env bash
#
# Extracts all cert-related content from local connectware instance.
#
CERT_DEPLOYMENT_CONTAINER=${1:-connectware_connectware_1}

CONTAINER_PATH="$CERT_DEPLOYMENT_CONTAINER:/connectware_certs"

DATE=`date '+%Y%m%d-%H%M'`
TARGET_DIR="certs-$DATE"
mkdir -p $TARGET_DIR

echo "copying certs folder from connectware volume to local directory..."
docker cp -L $CONTAINER_PATH $TARGET_DIR

echo "certificate copy done."

function displayCertInfo() {
  openssl x509 -in $1 -text -noout | grep "Issuer:\|Subject:"
}

echo "Certificate Infos:"
displayCertInfo $TARGET_DIR/connectware_certs/cybus_ca.crt

echo "Server Cert:"
displayCertInfo $TARGET_DIR/connectware_certs/cybus_server.crt

echo "Client Certs:"
displayCertInfo $TARGET_DIR/connectware_certs/cybus_client.crt

