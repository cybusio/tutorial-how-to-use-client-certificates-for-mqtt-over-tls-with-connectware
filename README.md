# How to use Mutual TLS (mTLS) Authentication with MQTT and Cybus Connectware

With a security-first approach to DevOps a company may decide to avoid exchange
of sensitive information in their network for authentication and authorization.

For example, using username/password as credentials for connecting machines to
Connectware should be replaced with public-key authentication using X.509 
client certificates to protect against authentication security threats. 

Using TLS v1.2 with Connectware is possible and recommended.
Kindly note that TLS v1.3 is currently not supported due to message broker limitations.

View also the guide to install Connectware and [how server certificates can be
replaced](https://www.cybus.io/learn/installing-the-connectware#changing-ssl-certificates)

For access with MQTT using mTLS 3 steps are required:
1. Prepare Connectware for mTLS
2. Create Certificate Signing Requests (CSR) and get signed client certificates
   * by using the built-in Cybus Certification Authority (CA). 
   * by using a custom CA resp. certificate chain
3. Create a Connectware user with role-based permissions
4. Assign role-based permissions for the client in Connectware

## 1. Prepare Connectware for mTLS

Connectware comes with a default behaviour with supporting username/password credentials,
allowing unencrypted or encrypted communication with the message broker (ports 1883/8883).

To use mTLS an environment variable has to be configured, which lets the broker change
the underlying authentication and authorization process. 

---
**NOTE**

TLS communication with the Connectware broker is either with username/password 
credentials or mTLS using client certificates, not both at the same time.
---

First, find the `.env` file of the Connectware installation (by default in `/opt/connectware`).
Change the `CYBUS_BROKER_USE_MUTUAL_TLS` setting to `yes`:

```
# Broker mutual TLS config
CYBUS_BROKER_USE_MUTUAL_TLS=yes
```

Second, restart the Connectware docker composition
(for this update on environment variables a `docker-compose restart` is NOT enough, 
first `down`, then `up -d` is required).

The Connectware now expects client certificates when connecting with MQTTS at port 8883.

To finalize the authentication process after a successful client certificate verification
the Common Name field (CN) of the client certificate is taken as a username.
This username must match a user in the Connectware auth-server database configured 
with the grant type "certificate".

### Verify basic settings

To test the Connectware with mTLS:
* use the prepared key-pair for a cybus_client with `CN=admin` stored in the /connectware_certs docker volume,
* then add the `certificate` grant type to the admin user with the Admin-UI
* and finally connect with a MQTT client on port 8883 with the CA and the client key-pair

---
**NOTE**

The grant type `certificate` is not assigned to the admin user by default,
so this has to be configured first.
---

To extract the `cybus_client.*` files use the [extract script](tools/extract_certs-from_connectware.sh),
which simply uses `docker cp` to copy files from a running container.

Then use a mqtt client like `mosquitto_sub` for example to see no connection issue:

```
 mosquitto_sub \
  --cert cybus_client.crt \
  --key cybus_client.key \
  --cafile cybus_ca.crt \
  -h localhost -p 8883 -t '#' -d
```

Example output on success:
```
Client mosq-wcdbhQtb5lkGOBMIbi sending CONNECT
Client mosq-wcdbhQtb5lkGOBMIbi received CONNACK (0)
Client mosq-wcdbhQtb5lkGOBMIbi sending SUBSCRIBE (Mid: 1, Topic: #, QoS: 0, Options: 0x00)
Client mosq-wcdbhQtb5lkGOBMIbi received SUBACK
Subscribed (mid: 1): 0
```

Example output on failing TLS handshake:
```
Client mosq-wcdbhQtb5lkGOBMIbi sending CONNECT
OpenSSL Error[0]: error:14094418:SSL routines:ssl3_read_bytes:tlsv1 alert unknown ca
Error: A TLS error occurred.
```

Example output on failing backend authorization:
```
Client mosq-wcdbhQtb5lkGOBMIbi sending CONNECT
Client mosq-wcdbhQtb5lkGOBMIbi  received CONNACK (5)
Connection error: Connection Refused: not authorised.
Client mosq-wcdbhQtb5lkGOBMIbi  sending DISCONNECT
```

## 2. Create Certificate Signing Requests (CSR) and get signed client certificates

To properly create client certificates use the recommended way with signing requests.

It is possible to use the internal self-signed Cybus Root CA created during 
setup of the Connectware instance.

Recommended is instead a proper PKI management with a CA certificate chain
matching the customer requirements. For example, managing client certificates 
for thousands of machines should be a task outside the Connectware.

To allow mTLS authentication for these certificates in the Connectware then 
just the CA certificate chain needs to be appended to the `cybus_ca.crt` file.

To start with a signing process first create a keypair use for one machine:
```
openssl genrsa -out anymachine-key.pem 2048
```

Then create an [openssl configuration file](resources/openssl-client-cert.conf).
The file in this project contains two settings that should be adjusted:
```
COMMON_NAME = device001
ORGNAME = Smart Factory Inc.
```

COMMON_NAME is essential as it needs to match the Connectware user later on.

We use the openssl configuration file instead of a command line dialog, 
in order to be more time efficient and to store the settings in a source repository.

The CSR is now built with:
```
openssl req -new \
   -config openssl-client-cert.conf \
   -key anymachine-key.pem \
   -out anymachine.csr
```

It is also possible to create both, private key and CSR, at once with `-keyout`
```
openssl req -new \
   -config openssl-client-cert.conf \
   -keyout anymachine-key.pem \
   -out anymachine.csr
```

Verify the generated CSR with
```
openssl req -in anymachine.csr -noout -text -nameopt sep_multiline
```

The most relevant information in the output at the beginning:
```
Certificate Request:
    Data:
        Version: 0 (0x0)
        Subject:
            C=DE
            O=Smart Factory Inc.
            CN=device001
```

### Signing with the built-in Cybus Certification Authority (CA).

After a CSR was created, use the Cybus CA to create a client certificate.

In an automated process there would be a service capable and eligible to do that
using an intermediate certificate authority. This ICA is regularly created to not
expose any part of the root certificate authority for an unsupervised action.

To sign the CSR the CA pair of certificate and key is required:
```
openssl x509 -req -in anymachine.csr -days 100 \
   -CA cybus_ca.crt \
   -CAkey cybus_ca.key \
   -set_serial 01 > anymachine.crt
```

This produces the signed certificate valid 100 days, and the output:
```
Signature ok
subject=/C=DE/O=Smart Factory Inc./CN=device001
Getting CA Private Key
```

By verifying the cert with:
```
openssl x509 -in anymachine.crt -text -noout
```

the Cybus CA as the issuer and the defined (100 days) validity can be seen:

```
Certificate:
    Data:
        Version: 1 (0x0)
        Serial Number: 1 (0x1)
    Signature Algorithm: sha1WithRSAEncryption
        Issuer: O=Cybus GmbH, OU=Development/emailAddress=hello@cybus.io, L=Hamburg, ST=Hamburg, C=DE, CN=CybusCA
        Validity
            Not Before: Jul 15 14:04:55 2021 GMT
            Not After : Oct 23 14:04:55 2021 GMT
        Subject: C=DE, O=Smart Factory Inc., CN=device001
```

This certificate can now be used for a MQTT over TLS connection,
after the corresponding user settings are added to the Connectware instance.

```
mosquitto_sub \
  --cert anymachine.crt \
  --key anymachine-key.pem \
  --cafile cybus-snapshot/cybus_ca.crt \
  -h localhost -p 8883 -t '#' -d
```

This may result in:
```
Client mosq-Saf49aFRd9u1I2Blg0 sending CONNECT
Client mosq-Saf49aFRd9u1I2Blg0 received CONNACK (0)
Client mosq-Saf49aFRd9u1I2Blg0 sending SUBSCRIBE (Mid: 1, Topic: #, QoS: 0, Options: 0x00)
Client mosq-Saf49aFRd9u1I2Blg0 received SUBACK
Subscribed (mid: 1): 0
```

In case of missing permission on the particular topic the `SUBACK` may show:
```
Subscribed (mid: 1): 128
```

Kindly note, that other MQTT clients present these results in another form.


### Signing with a custom CA

A manual or automated process for signing certificates with a company Root CA
or Intermediate CA is up to the customer.

In this tutorial we simply rely on the availability of a CA key-pair or a
corresponding Intermediate CA key-pair eligible to sign certificate requests.
(for testing use the [example root CA configuration](resources/openssl-root-ca-example.conf)
to get a new self-signed root CA).

The process then follows the above described steps.

To let the Connectware accept such client certificate, the internal `cybus_ca.crt`
file needs to be extended with the customer CA certificate chain:

```
cat custom_ca.crt >> cybus_ca.crt 
```

Verify this locally with:
```
openssl verify -CAfile cybus_ca.crt cybus_client.crt custom_client.crt 
```

This should result in:
```
cybus_client.crt: OK
anymachine.crt: OK
```

After that, use the [deployment script](tools/deploy_multiple_ca_file_to_connectware.sh)
to update the connectware with the new CA file acting as a custom trust store.

The client certificate can then be used as described above.


## 3. Create a Connectware user with role-based permission

To successfully connect with a client certificate, the Common Name (CN) entry
is required to match exactly a username in the Connectware auth-server database,
that is configured with grant type `certificate`.

The [User documentation](https://docs.cybus.io/latest/user/users.html#create-a-user-with-permissions)
show how this works. 
It is recommended to follow Principle of Least Privilege for
roles and permissions, but to test this use the `connectware_admin` role for now.

Corresponding API call (assuming a connectware instance on localhost):
```
curl -k --location --request POST 'https://localhost/api/users' \
--header 'Authorization: Bearer eyJzdWI...
--data-raw '{
    "username": "device001",
    "identityProvider": "local",
    "grantTypes": [ { "method": "certificate", "isRequired": false } ],
    "roles": [ "cfb72c04-e4a8-11eb-92a8-0242ac1e0006" ]
}'
```

To get the role id, use a GET call to `https://localhost/api/roles?name[eq]=connectware-admin`)

If the client now connects with mTLS using the certificate with CN=device001
and the corresponding CA certificate stored in the cybus_ca.crt file,
the connection should be successful.

## 4. Assign role-based permissions for the client in Connectware

As mentioned above, only required permissions should be assigned to clients.
Follow the [User documentation](https://docs.cybus.io/latest/user/users.html#create-a-user-with-permissions)
to reduce the permissions for the MQTT clients to more specific topic than `#`.

It is recommended to use a RBAC (role-based access control) approach by specifying
a role with permissions first, then assign the role(s) to the respective users.

## References

- [Cybus Connectware](https://docs.cybus.io/latest/index.html)
- [Cybus Learn - Installing the Connectware](https://www.cybus.io/learn/installing-the-connectware#changing-ssl-certificates)  
- [Cybus Learn - User Management Basics](https://www.cybus.io/learn/user-management-basics)
- [X.509](https://en.wikipedia.org/wiki/X.509)
- [OpenSSL PKI](https://pki-tutorial.readthedocs.io/en/latest/)
- [OpenSSL](https://www.openssl.org/)
- [Cybus](https://www.cybus.io/)
