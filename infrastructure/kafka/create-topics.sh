#!/usr/bin/env bash
set -euo pipefail
/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:19092 --create --if-not-exists --topic application.submitted --partitions 3 --replication-factor 1
/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:19092 --create --if-not-exists --topic application.submitted.DLT --partitions 3 --replication-factor 1
/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:19092 --create --if-not-exists --topic consent.updated --partitions 3 --replication-factor 1
/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:19092 --create --if-not-exists --topic consent.updated.DLT --partitions 3 --replication-factor 1
/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:19092 --create --if-not-exists --topic verification.completed --partitions 3 --replication-factor 1
/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:19092 --create --if-not-exists --topic verification.completed.DLT --partitions 3 --replication-factor 1
/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:19092 --create --if-not-exists --topic eligibility.completed --partitions 3 --replication-factor 1
/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:19092 --create --if-not-exists --topic eligibility.completed.DLT --partitions 3 --replication-factor 1
/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:19092 --create --if-not-exists --topic lender.application.submitted --partitions 3 --replication-factor 1
/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:19092 --create --if-not-exists --topic lender.application.submitted.DLT --partitions 3 --replication-factor 1
/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:19092 --create --if-not-exists --topic lender.information.requested --partitions 3 --replication-factor 1
/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:19092 --create --if-not-exists --topic lender.information.requested.DLT --partitions 3 --replication-factor 1
/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:19092 --create --if-not-exists --topic lender.decision.received --partitions 3 --replication-factor 1
/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:19092 --create --if-not-exists --topic lender.decision.received.DLT --partitions 3 --replication-factor 1
/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:19092 --create --if-not-exists --topic loan.offer.created --partitions 3 --replication-factor 1
/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:19092 --create --if-not-exists --topic loan.offer.created.DLT --partitions 3 --replication-factor 1
/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:19092 --create --if-not-exists --topic loan.offer.accepted --partitions 3 --replication-factor 1
/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:19092 --create --if-not-exists --topic loan.offer.accepted.DLT --partitions 3 --replication-factor 1
/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:19092 --create --if-not-exists --topic application.status.changed --partitions 3 --replication-factor 1
/opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:19092 --create --if-not-exists --topic application.status.changed.DLT --partitions 3 --replication-factor 1
