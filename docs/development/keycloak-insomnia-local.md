# Local Keycloak and authenticated API tests

Application Service runs locally on port 8081 and uses the service-owned Oracle schema. This guide adds Keycloak on 8180 and tests the implemented submission slice. Kafka publishing may remain disabled for these checks; this does not verify Audit delivery or the unimplemented consent/lender workflow.

## Start Keycloak without Docker

Download the official Keycloak 26.8.0 ZIP, extract it outside the Git repository, and use a supported JDK. The local verified setup uses JDK 25. From the repository root, run:

```powershell
.\scripts\Start-LocalKeycloak.ps1 -KeycloakHome 'C:\path\to\keycloak-26.8.0' -JavaHome 'C:\Jdk25'
```

The helper imports the CredFlow realm, binds HTTP to 127.0.0.1:8180 and uses the existing `.env` to supply client/user/admin credentials. The server stays in that terminal; Ctrl+C stops it. `-Background` starts it hidden and writes logs under repository `work/keycloak`, which is ignored by Git.

For the installation prepared in this chat, KeycloakHome is `C:\Users\Jithendra N\Documents\Codex\2026-10-13\go-x20\work\keycloak-runtime\keycloak-26.8.0`. Your Desktop repository can use the same KeycloakHome and matching copied `.env`. Only run one Keycloak process on 8180. Do not start another instance while the existing server is running.

Open http://localhost:8180/admin/ and sign in as `admin`, using your local `KEYCLOAK_ADMIN_PASSWORD`. Select realm `credflow`; inspect the mock-marketplace-client and the nine synthetic human users. Use your local DEMO_USER_PASSWORD for human accounts. No password grants are enabled.

Discovery should work at http://localhost:8180/realms/credflow/.well-known/openid-configuration. Its issuer must be http://localhost:8180/realms/credflow. The applications validate that issuer and the `credflow-api` audience.

Startup import skips an existing realm. Keep the same `.env` across restarts; generating new secrets does not update existing client credentials. Do not import a fresh realm over existing development state as routine troubleshooting.

## Insomnia requests

1. Token: POST `http://localhost:8180/realms/credflow/protocol/openid-connect/token`. Use No Auth and Form URL Encoded body with grant_type=client_credentials, client_id=mock-marketplace-client, and client_secret equal to MARKETPLACE_CLIENT_SECRET from your local .env. Expected 200 with access_token. Keep tokens/secrets local.
2. Create: POST `http://localhost:8081/api/v1/applications`. Choose Bearer Token authentication and paste only the access_token value. Add Content-Type: application/json, Idempotency-Key: insomnia-demo-105 and X-Correlation-ID: insomnia-flow-105. Copy contracts/examples/application-request.json as the JSON body, but change marketplaceSellerId to SELLER-105, marketplaceRequestId to REQ-105-001, sellerRequestReference to SELLER-REQUEST-105-001 and the consent evidenceReference to MARKETPLACE-CONSENT-105-001. This leaves seller104 available for the scripted test. Expected 201 and AWAITING_CONSENT.
3. Replay: resend the identical create request with the identical key. Expected 201 and the same applicationId, not a second application.
4. Read: GET `http://localhost:8081/api/v1/applications/{applicationId}` with the same bearer token. Expected 200 with the application.
5. Conflict: change requestedAmount to 400000.00 but retain the original key. Expected 409 IDEMPOTENCY_CONFLICT. Restore the original amount before later replays.
6. Active-application rule: send the original body with a new key. Expected 409 APPLICATION_ALREADY_ACTIVE. There is no automatic reset/cancellation endpoint implemented yet.

Use a fresh token when it expires. A 401 indicates absent/invalid/expired token or issuer/audience/signing-key validation failure. A 403 indicates permissions/marketplace mismatch. Check tokens locally; do not paste them into chat.

## Scripted equivalent

```powershell
.\scripts\Test-AuthenticatedSubmission.ps1
```

The helper uses seller104 and stable key authenticated-local-104. It verifies creation, same-key replay, permitted read and different-body conflict without printing tokens/secrets. If seller104 already has an active application from a different key, use the original key/request or a different seeded seller; do not remove production-style history to make a test pass. This helper does not verify Kafka or Audit.

Sources: [Keycloak native startup](https://www.keycloak.org/getting-started/getting-started-zip), [realm import and environment substitution](https://www.keycloak.org/server/importExport).
