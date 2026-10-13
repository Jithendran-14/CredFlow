# Oracle and cross-service acceptance

This directory is reserved for Oracle-backed and full-flow checks. The default Maven suite verifies Java behaviour without external infrastructure; these checks are still to implement.

First acceptance: start the Compose infrastructure and Application/Audit/Gateway, seed sellers, submit with the smoke script, and inspect the service-owned SQL reports. Verify one application, one stable published event and one Audit/inbox record. Repeat with a Kafka interruption and duplicate delivery.

Member 2 adds Oracle package fixture checks including month boundaries, returns, complete zero months, incomplete coverage and rollback. All three members add the Day 6 application-to-acceptance test and the remaining security/failure scenarios. Never test the financial PL/SQL package against H2.
