# STS with an existing local Oracle database

For the connection named CredFlowDB, host localhost, port 1521 and service FREEPDB1, the JDBC URL is `jdbc:oracle:thin:@localhost:1521/FREEPDB1`. CredFlowDB is the saved client connection label. SYSTEM is an administrative setup account, not the application's database user.

## Create and verify the service users

From the repository root in PowerShell, generate `.env` only if it does not already exist, then run:

```powershell
.\scripts\New-LocalEnvironment.ps1
.\scripts\Setup-LocalOracle.ps1
.\scripts\Test-LocalOracle.ps1
```

Setup prompts securely for SYSTEM's password; do not put it in chat or commit it. SQL*Plus must be on PATH. Alternatively pass `-SqlPlus 'C:\path\to\sqlplus.exe'`. On a local installation where your Windows user has Oracle DBA rights, `Setup-LocalOracle.ps1 -UseOsAuthentication` can perform the same setup without a SYSTEM password.

The script creates only the six CF service users, with schema-specific local passwords and limited object-creation grants. Existing passwords are preserved. It does not change SYSTEM, drop objects or reset demo data. DDL is committed by Oracle; if a later step fails, fix the cause and rerun. Connection checks must all pass before starting the services.

## Start Application Service in STS

1. Import the repository root through File → Import → Maven → Existing Maven Projects. Select JDK 21 and update the Maven projects.
2. Open Run → Run Configurations → Spring Boot App. Select `ApplicationServiceApplication`.
3. In Environment add `CF_APPLICATION_PASSWORD` with the matching value from your local `.env`. Add `ORACLE_JDBC_URL=jdbc:oracle:thin:@localhost:1521/FREEPDB1`. Its configured username remains CF_APPLICATION.
4. For the initial database-only check, in Arguments → Program arguments add `--credflow.outbox.enabled=false`. This prevents attempts to publish to Kafka while you are checking Oracle. It does not enable consent or the rest of the workflow.
5. Run the application. Check that Flyway succeeds and `http://localhost:8081/actuator/health` returns UP.
6. Run `scripts/Seed-DemoLocal.ps1` from PowerShell after the service has started. It uses SQL*Plus directly and needs no Docker.

The password variable is required. STS does not automatically read `.env`. Never switch the service username to SYSTEM. Flyway runs as each service's own user and creates that service's tables.

As a command-line equivalent after building with `mvnw.cmd verify`:

```powershell
. .\scripts\Import-LocalEnvironment.ps1
java -jar backend/application-service/target/application-service-0.1.0-SNAPSHOT.jar --credflow.outbox.enabled=false
```

## Inspect tables in SQL Developer

Create a second saved connection named CredFlowApplication: username CF_APPLICATION, password matching `.env`, host localhost, port 1521, service FREEPDB1. Inspect SELLER_PROFILE, LOAN_APPLICATION, API_IDEMPOTENCY, EVENT_OUTBOX, EVENT_INBOX and the Flyway history table. Connect as the other service users to inspect their own tables after starting those services.

## Continue to the complete local stack

Application database connectivity and health do not prove authenticated submission or Kafka delivery. Run Kafka and Keycloak locally or use shared endpoints. Import the supplied Keycloak realm with its environment placeholders configured, initialize the Kafka topics, remove `--credflow.outbox.enabled=false`, then start Audit and Gateway. Use the existing submission smoke script once authentication is available. Audit's initial database-only launch additionally needs `--credflow.audit.consumer-enabled=false`.

Kafka/Keycloak native startup is separate from this Oracle setup. The services already support host URL overrides. Do not claim the full workflow is running from an Oracle health check alone.

Oracle references: [CREATE USER](https://docs.oracle.com/en/database/oracle/oracle-database/26/sqlrf/CREATE-USER.html) and [SQL*Plus error exit handling](https://docs.oracle.com/en/database/oracle/oracle-database/18/sqpug/WHENEVER-SQLERROR.html).
