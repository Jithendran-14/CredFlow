#!/usr/bin/env bash
(
set -euo pipefail
sql_file=$(mktemp)
trap 'rm -f "$sql_file"' EXIT
printf '%s\n' 'WHENEVER SQLERROR EXIT FAILURE ROLLBACK' 'SET ECHO OFF VERIFY OFF' 'ALTER SESSION SET CONTAINER=FREEPDB1;' > "$sql_file"
password="${CF_APPLICATION_PASSWORD:?Missing CF_APPLICATION_PASSWORD}"
[[ "$password" =~ ^[A-Za-z0-9_]+$ ]] || { echo 'Schema passwords must use letters, numbers and underscores.' >&2; exit 1; }
printf 'CREATE USER CF_APPLICATION IDENTIFIED BY "%s" DEFAULT TABLESPACE USERS QUOTA 200M ON USERS;\n' "$password" >> "$sql_file"
printf '%s\n' 'GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE, CREATE PROCEDURE, CREATE TRIGGER, CREATE VIEW TO CF_APPLICATION;' >> "$sql_file"
password="${CF_CONSENT_PASSWORD:?Missing CF_CONSENT_PASSWORD}"
[[ "$password" =~ ^[A-Za-z0-9_]+$ ]] || { echo 'Schema passwords must use letters, numbers and underscores.' >&2; exit 1; }
printf 'CREATE USER CF_CONSENT IDENTIFIED BY "%s" DEFAULT TABLESPACE USERS QUOTA 200M ON USERS;\n' "$password" >> "$sql_file"
printf '%s\n' 'GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE, CREATE PROCEDURE, CREATE TRIGGER, CREATE VIEW TO CF_CONSENT;' >> "$sql_file"
password="${CF_ELIGIBILITY_PASSWORD:?Missing CF_ELIGIBILITY_PASSWORD}"
[[ "$password" =~ ^[A-Za-z0-9_]+$ ]] || { echo 'Schema passwords must use letters, numbers and underscores.' >&2; exit 1; }
printf 'CREATE USER CF_ELIGIBILITY IDENTIFIED BY "%s" DEFAULT TABLESPACE USERS QUOTA 200M ON USERS;\n' "$password" >> "$sql_file"
printf '%s\n' 'GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE, CREATE PROCEDURE, CREATE TRIGGER, CREATE VIEW TO CF_ELIGIBILITY;' >> "$sql_file"
password="${CF_ORCHESTRATION_PASSWORD:?Missing CF_ORCHESTRATION_PASSWORD}"
[[ "$password" =~ ^[A-Za-z0-9_]+$ ]] || { echo 'Schema passwords must use letters, numbers and underscores.' >&2; exit 1; }
printf 'CREATE USER CF_ORCHESTRATION IDENTIFIED BY "%s" DEFAULT TABLESPACE USERS QUOTA 200M ON USERS;\n' "$password" >> "$sql_file"
printf '%s\n' 'GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE, CREATE PROCEDURE, CREATE TRIGGER, CREATE VIEW TO CF_ORCHESTRATION;' >> "$sql_file"
password="${CF_LENDER_INTEGRATION_PASSWORD:?Missing CF_LENDER_INTEGRATION_PASSWORD}"
[[ "$password" =~ ^[A-Za-z0-9_]+$ ]] || { echo 'Schema passwords must use letters, numbers and underscores.' >&2; exit 1; }
printf 'CREATE USER CF_LENDER_INTEGRATION IDENTIFIED BY "%s" DEFAULT TABLESPACE USERS QUOTA 200M ON USERS;\n' "$password" >> "$sql_file"
printf '%s\n' 'GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE, CREATE PROCEDURE, CREATE TRIGGER, CREATE VIEW TO CF_LENDER_INTEGRATION;' >> "$sql_file"
password="${CF_AUDIT_PASSWORD:?Missing CF_AUDIT_PASSWORD}"
[[ "$password" =~ ^[A-Za-z0-9_]+$ ]] || { echo 'Schema passwords must use letters, numbers and underscores.' >&2; exit 1; }
printf 'CREATE USER CF_AUDIT IDENTIFIED BY "%s" DEFAULT TABLESPACE USERS QUOTA 200M ON USERS;\n' "$password" >> "$sql_file"
printf '%s\n' 'GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE, CREATE PROCEDURE, CREATE TRIGGER, CREATE VIEW TO CF_AUDIT;' >> "$sql_file"
printf '%s\n' 'EXIT' >> "$sql_file"
sqlplus -s / as sysdba @"$sql_file"
)
