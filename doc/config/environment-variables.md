# Environment Variables

This document contains all the environment variables which are available for this application.

| Name | Type | Description | Default |
| ---- | ---- | ----------- | ------- |
| `POSTAL_WEB_HOSTNAME` | String | The hostname that the Postal web interface runs on | postal.example.com |
| `POSTAL_WEB_PROTOCOL` | String | The HTTP protocol to use for the Postal web interface | https |
| `POSTAL_SMTP_HOSTNAME` | String | The hostname that the Postal SMTP server runs on | postal.example.com |
| `POSTAL_USE_IP_POOLS` | Boolean | Should IP pools be enabled for this installation? | false |
| `POSTAL_DEFAULT_MAXIMUM_DELIVERY_ATTEMPTS` | Integer | The maximum number of delivery attempts | 18 |
| `POSTAL_DEFAULT_MAXIMUM_HOLD_EXPIRY_DAYS` | Integer | The number of days to hold a message before they will be expired | 7 |
| `POSTAL_DEFAULT_SUPPRESSION_LIST_AUTOMATIC_REMOVAL_DAYS` | Integer | The number of days an address will remain in a suppression list before being removed | 30 |
| `POSTAL_DEFAULT_SPAM_THRESHOLD` | Integer | The default threshold at which a message should be treated as spam | 5 |
| `POSTAL_DEFAULT_SPAM_FAILURE_THRESHOLD` | Integer | The default threshold at which a message should be treated as spam failure | 20 |
| `POSTAL_USE_LOCAL_NS_FOR_DOMAIN_VERIFICATION` | Boolean | Domain verification and checking usually checks with a domain's nameserver. Enable this to check with the server's local nameservers. | false |
| `POSTAL_USE_RESENT_SENDER_HEADER` | Boolean | Append a Resend-Sender header to all outgoing e-mails | true |
| `POSTAL_SIGNING_KEY_PATH` | String | Path to the private key used for signing | $config-file-root/signing.key |
| `POSTAL_SMTP_RELAYS` | Array of strings | An array of SMTP relays in the format of smtp://host:port | [] |
| `POSTAL_TRUSTED_PROXIES` | Array of strings | An array of IP addresses to trust for proxying requests to Postal (in addition to localhost addresses) | [] |
| `POSTAL_QUEUED_MESSAGE_LOCK_STALE_DAYS` | Integer | The number of days after which to consider a lock as stale. Messages with stale locks will be removed and not retried. | 1 |
| `POSTAL_BATCH_QUEUED_MESSAGES` | Boolean | When enabled queued messages will be de-queued in batches based on their destination | true |
| `WEB_SERVER_DEFAULT_PORT` | Integer | The default port the web server should listen on unless overriden by the PORT environment variable | 5000 |
| `WEB_SERVER_DEFAULT_BIND_ADDRESS` | String | The default bind address the web server should listen on unless overriden by the BIND_ADDRESS environment variable | 127.0.0.1 |
| `WEB_SERVER_MAX_THREADS` | Integer | The maximum number of threads which can be used by the web server | 5 |
| `WORKER_DEFAULT_HEALTH_SERVER_PORT` | Integer | The default port for the worker health server to listen on | 9090 |
| `WORKER_DEFAULT_HEALTH_SERVER_BIND_ADDRESS` | String | The default bind address for the worker health server to listen on | 127.0.0.1 |
| `WORKER_THREADS` | Integer | The number of threads to execute within each worker | 2 |
| `MAIN_DB_HOST` | String | Hostname for the main MariaDB server | localhost |
| `MAIN_DB_PORT` | Integer | The MariaDB port to connect to | 3306 |
| `MAIN_DB_USERNAME` | String | The MariaDB username | postal |
| `MAIN_DB_PASSWORD` | String | The MariaDB password |  |
| `MAIN_DB_DATABASE` | String | The MariaDB database name | postal |
| `MAIN_DB_POOL_SIZE` | Integer | The maximum size of the MariaDB connection pool | 5 |
| `MAIN_DB_ENCODING` | String | The encoding to use when connecting to the MariaDB database | utf8mb4 |
| `MESSAGE_DB_HOST` | String | Hostname for the MariaDB server which stores the mail server databases | localhost |
| `MESSAGE_DB_PORT` | Integer | The MariaDB port to connect to | 3306 |
| `MESSAGE_DB_USERNAME` | String | The MariaDB username | postal |
| `MESSAGE_DB_PASSWORD` | String | The MariaDB password |  |
| `MESSAGE_DB_ENCODING` | String | The encoding to use when connecting to the MariaDB database | utf8mb4 |
| `MESSAGE_DB_DATABASE_NAME_PREFIX` | String | The MariaDB prefix to add to database names | postal |
| `LOGGING_RAILS_LOG_ENABLED` | Boolean | Enable the default Rails logger | false |
| `LOGGING_SENTRY_DSN` | String | A DSN which should be used to report exceptions to Sentry |  |
| `LOGGING_ENABLED` | Boolean | Enable the Postal logger to log to STDOUT | true |
| `LOGGING_HIGHLIGHTING_ENABLED` | Boolean | Enable highlighting of log lines | false |
| `GELF_HOST` | String | GELF-capable host to send logs to |  |
| `GELF_PORT` | Integer | GELF port to send logs to | 12201 |
| `GELF_FACILITY` | String | The facility name to add to all log entries sent to GELF | postal |
| `SMTP_SERVER_DEFAULT_PORT` | Integer | The default port the SMTP server should listen on unless overriden by the PORT environment variable | 25 |
| `SMTP_SERVER_DEFAULT_BIND_ADDRESS` | String | The default bind address the SMTP server should listen on unless overriden by the BIND_ADDRESS environment variable | :: |
| `SMTP_SERVER_DEFAULT_HEALTH_SERVER_PORT` | Integer | The default port for the SMTP server health server to listen on | 9091 |
| `SMTP_SERVER_DEFAULT_HEALTH_SERVER_BIND_ADDRESS` | String | The default bind address for the SMTP server health server to listen on | 127.0.0.1 |
| `SMTP_SERVER_TLS_ENABLED` | Boolean | Enable TLS for the SMTP server (requires certificate) | false |
| `SMTP_SERVER_TLS_CERTIFICATE_PATH` | String | The path to the SMTP server's TLS certificate | $config-file-root/smtp.cert |
| `SMTP_SERVER_TLS_PRIVATE_KEY_PATH` | String | The path to the SMTP server's TLS private key | $config-file-root/smtp.key |
| `SMTP_SERVER_TLS_CIPHERS` | String | Override ciphers to use for SSL |  |
| `SMTP_SERVER_SSL_VERSION` | String | The SSL versions which are supported | SSLv23 |
| `SMTP_SERVER_PROXY_PROTOCOL` | Boolean | Enable proxy protocol for use behind some load balancers (supports proxy protocol v1 only) | false |
| `SMTP_SERVER_LOG_CONNECTIONS` | Boolean | Enable connection logging | false |
| `SMTP_SERVER_MAX_MESSAGE_SIZE` | Integer | The maximum message size to accept from the SMTP server (in MB) | 14 |
| `SMTP_SERVER_LOG_IP_ADDRESS_EXCLUSION_MATCHER` | String | A regular expression to use to exclude connections from logging |  |
| `DNS_MX_RECORDS` | Array of strings | The names of the default MX records | ["mx1.postal.example.com", "mx2.postal.example.com"] |
| `DNS_SPF_INCLUDE` | String | The location of the SPF record | spf.postal.example.com |
| `DNS_RETURN_PATH_DOMAIN` | String | The return path hostname | rp.postal.example.com |
| `DNS_ROUTE_DOMAIN` | String | The domain to use for hosting route-specific addresses | routes.postal.example.com |
| `DNS_TRACK_DOMAIN` | String | The CNAME which tracking domains should be pointed to | track.postal.example.com |
| `DNS_HELO_HOSTNAME` | String | The hostname to use in HELO/EHLO when connecting to external SMTP servers |  |
| `DNS_DKIM_IDENTIFIER` | String | The identifier to use for DKIM keys in DNS records | postal |
| `DNS_DOMAIN_VERIFY_PREFIX` | String | The prefix to add before TXT record verification string | postal-verification |
| `DNS_CUSTOM_RETURN_PATH_PREFIX` | String | The domain to use on external domains which points to the Postal return path domain | psrp |
| `DNS_TIMEOUT` | Integer | The timeout to wait for DNS resolution | 5 |
| `DNS_RESOLV_CONF_PATH` | String | The path to the resolv.conf file containing addresses for local nameservers | /etc/resolv.conf |
| `SMTP_HOST` | String | The hostname to send application-level e-mails to | 127.0.0.1 |
| `SMTP_PORT` | Integer | The port number to send application-level e-mails to | 25 |
| `SMTP_USERNAME` | String | The username to use when authentication to the SMTP server |  |
| `SMTP_PASSWORD` | String | The password to use when authentication to the SMTP server |  |
| `SMTP_AUTHENTICATION_TYPE` | String | The type of authentication to use | login |
| `SMTP_ENABLE_STARTTLS` | Boolean | Use STARTTLS when connecting to the SMTP server and fail if unsupported | false |
| `SMTP_ENABLE_STARTTLS_AUTO` | Boolean | Detects if STARTTLS is enabled in the SMTP server and starts to use it | true |
| `SMTP_OPENSSL_VERIFY_MODE` | String | When using TLS, you can set how OpenSSL checks the certificate. Use 'none' for no certificate checking | peer |
| `SMTP_FROM_NAME` | String | The name to use as the from name outgoing emails from Postal | Postal |
| `SMTP_FROM_ADDRESS` | String | The e-mail to use as the from address outgoing emails from Postal | postal@example.com |
| `RAILS_ENVIRONMENT` | String | The Rails environment to run the application in | production |
| `RAILS_SECRET_KEY` | String | The secret key used to sign and encrypt cookies and session data in the application |  |
| `RSPAMD_ENABLED` | Boolean | Enable rspamd for message inspection | false |
| `RSPAMD_HOST` | String | The hostname of the rspamd server | 127.0.0.1 |
| `RSPAMD_PORT` | Integer | The port of the rspamd server | 11334 |
| `RSPAMD_SSL` | Boolean | Enable SSL for the rspamd connection | false |
| `RSPAMD_PASSWORD` | String | The password for the rspamd server |  |
| `RSPAMD_FLAGS` | String | Any flags for the rspamd server |  |
| `SPAMD_ENABLED` | Boolean | Enable SpamAssassin for message inspection | false |
| `SPAMD_HOST` | String | The hostname for the SpamAssassin server | 127.0.0.1 |
| `SPAMD_PORT` | Integer | The port of the SpamAssassin server | 783 |
| `CLAMAV_ENABLED` | Boolean | Enable ClamAV for message inspection | false |
| `CLAMAV_HOST` | String | The host of the ClamAV server | 127.0.0.1 |
| `CLAMAV_PORT` | Integer | The port of the ClamAV server | 2000 |
| `SMTP_CLIENT_OPEN_TIMEOUT` | Integer | The open timeout for outgoing SMTP connections | 30 |
| `SMTP_CLIENT_READ_TIMEOUT` | Integer | The read timeout for outgoing SMTP connections | 30 |
| `MIGRATION_WAITER_ENABLED` | Boolean | Wait for all migrations to run before starting a process | false |
| `MIGRATION_WAITER_ATTEMPTS` | Integer | The number of attempts to try waiting for migrations to complete before start | 120 |
| `MIGRATION_WAITER_SLEEP_TIME` | Integer | The number of seconds to wait between each migration check | 2 |
| `OIDC_ENABLED` | Boolean | Enable OIDC authentication | false |
| `OIDC_LOCAL_AUTHENTICATION_ENABLED` | Boolean | When enabled, users with passwords will still be able to login locally. If disable, only OpenID Connect will be available. | true |
| `OIDC_NAME` | String | The name of the OIDC provider as shown in the UI | OIDC Provider |
| `OIDC_ISSUER` | String | The OIDC issuer URL |  |
| `OIDC_PKCE` | Boolean | Option to enable Proof Key for Code Exchange by OAuth Public Clients | false |
| `OIDC_IDENTIFIER` | String | The client ID for OIDC |  |
| `OIDC_SECRET` | String | The client secret for OIDC |  |
| `OIDC_SCOPES` | Array of strings | Scopes to request from the OIDC server. | openid,email |
| `OIDC_UID_FIELD` | String | The field to use to determine the user's UID | sub |
| `OIDC_EMAIL_ADDRESS_FIELD` | String | The field to use to determine the user's email address | email |
| `OIDC_NAME_FIELD` | String | The field to use to determine the user's name | name |
| `OIDC_DISCOVERY` | Boolean | Enable discovery to determine endpoints from .well-known/openid-configuration from the Issuer | true |
| `OIDC_AUTHORIZATION_ENDPOINT` | String | The authorize endpoint on the authorization server (only used when discovery is false) |  |
| `OIDC_TOKEN_ENDPOINT` | String | The token endpoint on the authorization server (only used when discovery is false) |  |
| `OIDC_USERINFO_ENDPOINT` | String | The user info endpoint on the authorization server (only used when discovery is false) |  |
| `OIDC_JWKS_URI` | String | The JWKS endpoint on the authorization server (only used when discovery is false) |  |
