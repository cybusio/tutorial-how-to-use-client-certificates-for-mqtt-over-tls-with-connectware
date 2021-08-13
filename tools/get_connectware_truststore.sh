#!/usr/bin/env bash
#
# Downloads and displays the truststore from the Connectware instance (cybus_ca.crt).
#
CERT_DEPLOYMENT_CONTAINER=${1:-connectware_connectware_1}
CONTAINER_PATH="$CERT_DEPLOYMENT_CONTAINER:/connectware_certs"

echo "copying cybus_ca.crt from connectware volume to local directory..."
docker cp -L $CONTAINER_PATH cybus_ca.crt

echo "truststore copy done."

function displayCertInfo() {
  openssl x509 -in $1 -text -noout | grep "Issuer:\|Subject:"
}

echo "Certificate Info:"
displayCertInfo cybus_ca.crt
