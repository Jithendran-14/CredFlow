# Member 3 implementation decisions

Recorded 2026-10-16 against the supplied team allocation and corrected development plan. “Implemented” below describes this source delivery, not trainer approval, teammate approval or a successful live environment test.

| Decision | Basis and implemented choice | Integration consequence |
| --- | --- | --- |
| Oracle throughout Member 3 | User explicitly requested Oracle only, overriding document H2 defaults for simulator lenders. Orchestration/Integration use CF_ORCHESTRATION/CF_LENDER_INTEGRATION; the independent lender applications connect to distinct Oracle users CF_SIM_BANK_A/CF_SIM_NBFC_B. | Prepare four owning schemas manually. No H2 runtime and no cross-schema business queries. |
| Manual migrations | User retained database creation/migrations. Hibernate uses validate. Read-only reports and a column checklist are supplied, not a migration that creates/changes tables. | Existing tables must include every mapped column, constraint and required sequence before startup. |
| API-only delivery | User requested no frontend. Document explicitly allows authenticated API demonstration. | Expose/document seller and lender APIs for later Gateway clients; no UI added. |
| Eligibility enum | Corrected plan specifies EVALUATED/ACTION_REQUIRED. | EVALUATED derives routing/no-eligible outcome from lenderResults; legacy overall ELIGIBLE/NOT_ELIGIBLE is rejected. |
| Snapshot ownership | Eligibility's BUILD_SNAPSHOT package returns its immutable snapshot ID. | Orchestration allocates evaluationRequestId; current trusted result binds financialSnapshotId and eligibilityResultId after revision/verification/request checks. Request does not invent a snapshot ID. |
| Immutable result binding | One expected evaluation result per current request. | Identical replay is harmless; changed snapshot/result/data for the same accepted request conflicts; a refresh/correction creates a new request. |
| Question enum | Document limits question status to OPEN/ANSWERED/CANCELLED. | A newly available offer cancels obsolete open questions. Late answer acknowledgements do not move the application back into review. No SUPERSEDED enum. |
| Submission cancellation | Document separates lender decision state from cancellation acknowledgement. | Application becomes CANCELLED; Orchestration's submission retains its documented last decision/review state and tracks cancellation acknowledgement separately. Integration may have an internal cancellation/tombstone state. |
| Organisation restrictions | Document requires resource-level organisation checks. | Trusted opaque sellerId, marketplaceId and lenderId come from signed Auth claims and stored Application mapping; legacy claims remain explicit compatibility options. Ops can read own-marketplace workflow/status and the safe submission queue, not questions/answers/offers/full profiles. Lists filter both items and total count. Inaccessible individual resources return 404. |
| Durable technical health | Document separates failures from business rejection. | Stable per-job/task issues, resolved tombstones and explicit recovered events prevent one successful retry from clearing unrelated failures. Obsolete protected HTTP work rechecks consent/revision before sending. |
| Trace continuity | Document requires X-Correlation-ID and actor provenance throughout asynchronous flow. | Adapters, persisted simulator callbacks and normalized Kafka events preserve the initial trace; immediate actor remains distinct from trusted originActor/causationId. |
| Optional document references | Document marks syntheticDocumentReferences optional. | Omission becomes an empty list. Only synthetic references are accepted; uploads remain outside scope. |
| List responses | Shared baseline defines a paginated envelope. | Submissions, offers and information requests use items/page/size/totalElements; page starts at 0, size defaults 20, maximum 100. |
| Queued operation references | Document requires an operation reference after durable asynchronous acceptance. | Answers return the durable job operationId; refresh/cancellation return operationId plus workflow. Workflow exposes current expected result IDs; offers expose acceptanceId/acceptedAt when available. Poll the corresponding authorised resource. |
| Oracle type stability | Oracle-only schemas are manually managed. | UUID uses RAW(16), boolean uses explicitly configured NUMERIC/NUMBER(1), Instant uses UTC timestamp mapping. Confirm actual runtime metadata with the Oracle checks. |
| Service boundaries | Six business services, Gateway and one simulator are the team baseline. Only Member 3 sources are supplied here. | No direct M1/M2 schema access; no fake Application/Consent/Eligibility/Audit production implementation. Their routes/events and Gateway deployment must be jointly reconciled. |

## Joint contracts requiring real integration confirmation

The contracts, ports and configured client names in this delivery are explicit proposed implementation contracts based on the existing project and corrected document. The two supplied Member 1/2 contracts are now preserved under contracts/upstream. They are specifications, with many external APIs and publishers explicitly marked pending; teammate source and live credentials were not supplied. Confirm their implementation of application-submitted/revised enrichment, consent operation acknowledgement, verification and eligibility evaluation requests/results, monotonic workflow status projection and Audit actor/correlation storage.

Member 1 must provision the real issuer/audiences, UI role client, organisation claim mappers and separate machine clients/scopes, and publish the intended public Gateway routes. Member 2 must provision Kafka topics/DLT topics/ACLs and align Eligibility's returned snapshot IDs and Audit consumption. Member 3 supplies two independently deployed lender simulators and their Integration adapters. Marketplace/provider modules remain owned by Members 1/2 and their upstream shared mock remains separate.

## Evidence boundary

Offline tests establish behavior/configuration contracts under their documented fixtures. They do not establish Oracle schema availability, real JWT mappers, Kafka ACLs/delivery, teammate APIs or a complete shared journey. Run the opt-in Oracle checks and repeatable authenticated API scenarios in the actual environment; capture logs, owning-schema SQL reports and Audit evidence before marking the project complete. Feature completion and verified deployment are separate claims.

## Later team contracts take precedence

Use docs/team-contract-alignment.md for the new exact Eligibility path/six inputs, captured date/operation receipt, three financial ACTION_REQUIRED reasons, string seller identities, explicit custom RS256 configuration and Integration8087. Upstream flat/envelope event compatibility and dedicated service grants remain joint gates. Financial ACTIVE consent is distinct from operational GRANTED workflow consent; no scope escalation or initial-consent shortcut is enabled.

## Independent lender deployment update

The user subsequently requested four independent Member 3 applications. This
overrides the earlier combined simulator deployment choice. The upstream provider
mock on8090 remains a teammate contribution. Only Member 3 lender endpoints move
to8091 and8092; their request/response formats and callback contracts are retained.
