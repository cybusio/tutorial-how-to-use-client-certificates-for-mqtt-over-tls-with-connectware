#!/usr/bin/env bash
#
# Validates a key-pair (PEM-encoded Private Key and Certificate)
#
CLIENT_CERT_NAME=${1:?Specify name of the certificate that matches the keypair}

CERT_DIGEST=`openssl x509 -noout -modulus -in $CLIENT_CERT_NAME.crt | openssl sha1`
KEY_DIGEST=`openssl rsa  -noout -modulus -in $CLIENT_CERT_NAME.key | openssl sha1`

echo "Client Name: $CLIENT_CERT_NAME"
echo "-------------------------------"
echo "Digest of Cert: $CERT_DIGEST"
echo "Digest of Key:  $KEY_DIGEST"

if [ "$CERT_DIGEST" == "$KEY_DIGEST" ]; then
  echo "Key-pair is valid"
  exit 0
else
  echo "Key-pair is invalid (key and cert digest do not match)"
  exit 1
fi
