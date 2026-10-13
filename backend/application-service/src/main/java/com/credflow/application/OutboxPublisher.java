package com.credflow.application;
import java.util.concurrent.TimeUnit;
import org.slf4j.*;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.scheduling.annotation.*;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;
@Component @ConditionalOnProperty(name="credflow.outbox.enabled",havingValue="true",matchIfMissing=true)
public class OutboxPublisher {
    private static final Logger log=LoggerFactory.getLogger(OutboxPublisher.class);
    private final JdbcTemplate jdbc; private final KafkaTemplate<String,String> kafka; private final TransactionTemplate tx;
    public OutboxPublisher(JdbcTemplate jdbc,KafkaTemplate<String,String> kafka,TransactionTemplate tx) { this.jdbc=jdbc; this.kafka=kafka; this.tx=tx; }
    @Scheduled(fixedDelayString="${credflow.outbox.interval-ms:2000}") public void publish() {
        tx.executeWithoutResult(status -> {
            var rows=jdbc.queryForList("SELECT event_id,application_id,event_type,payload FROM event_outbox WHERE published_at IS NULL AND attempts < 5 AND ROWNUM <= 20 FOR UPDATE SKIP LOCKED");
            for(var row:rows) {
                String id=(String)row.get("EVENT_ID");
                try {
                    String payload=jdbc.queryForObject("SELECT payload FROM event_outbox WHERE event_id=?",String.class,id);
                    kafka.send((String)row.get("EVENT_TYPE"),(String)row.get("APPLICATION_ID"),payload).get(10,TimeUnit.SECONDS);
                    jdbc.update("UPDATE event_outbox SET published_at=SYSTIMESTAMP,attempts=attempts+1 WHERE event_id=?",id);
                } catch(Exception ex) {
                    if(ex instanceof InterruptedException) Thread.currentThread().interrupt();
                    jdbc.update("UPDATE event_outbox SET attempts=attempts+1 WHERE event_id=?",id);
                    log.warn("Outbox delivery pending eventId={} errorType={}",id,ex.getClass().getSimpleName());
                }
            }
        });
    }
    @Configuration @EnableScheduling static class Scheduling {}
}
