# Access matrix

| Action | Allowed role | Required resource relationship | Status |
|---|---|---|---|
| Submit application | MARKETPLACE_CLIENT or MARKETPLACE_OPERATIONS | Token organisation equals marketplace; registered seller belongs to marketplace; seller request and sharing evidence supplied | Implemented; independent evidence verification pending |
| Read application by ID | SELLER | Keycloak subject equals linked seller subject | Implemented |
| Read application by ID | MARKETPLACE_CLIENT or MARKETPLACE_OPERATIONS | Token organisation equals application's marketplace | Implemented |
| Read application by ID | ADMIN | MVP global training admin | Implemented |
| Query application Audit | ADMIN | MVP global training admin | Implemented |
| Grant/decline/revoke consent | SELLER | Own application; Orchestration guards state | Planned |
| Read verification/eligibility | SELLER or authorised service | Own application or explicit internal permission | Planned |
| Lender actions/callbacks | LENDER_OFFICER or LENDER_CLIENT respectively | Token lender matches submission lender | Planned |
| Manage product rules | ADMIN | Training admin | Planned |
| Internal ownership/workflow calls | SERVICE | Allowed calling client and action; caller authenticates with own client | Planned |
| Health GET | Public | Minimal health only | Implemented |
| Metrics | ADMIN on service directly | Training admin; gateway denies other actuator routes | Implemented |

Every protected service validates issuer, JWT time constraints, and `credflow-api` audience. Roles derive from Keycloak `realm_access.roles`. Organisation claims derive from configured identity attributes. Never accept public actor/role fields as authority. Sharing permission assertions require validation before protected processing is built.

Human login uses Authorization Code with PKCE. Machine clients use client credentials. Nine human seed accounts are synthetic. Secrets are generated into local `.env` and substituted into the imported realm; no fixed passwords are committed. Realm import is for local development only and is skipped when the realm already exists.

Kafka producer identity and actor provenance are trusted only within this local development broker. Before using a shared/remote broker, add broker authentication and producer/consumer ACLs. Do not expose this local infrastructure as a deployment.
