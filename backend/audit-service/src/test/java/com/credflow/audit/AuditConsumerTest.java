package com.credflow.audit;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import com.fasterxml.jackson.databind.ObjectMapper;
import static org.assertj.core.api.Assertions.*;
@SpringBootTest(properties={"spring.datasource.url=jdbc:h2:mem:audit-events;MODE=Oracle;DB_CLOSE_DELAY=-1","spring.datasource.driver-class-name=org.h2.Driver","spring.datasource.username=sa","spring.datasource.password=","spring.flyway.enabled=false","spring.jpa.hibernate.ddl-auto=none","spring.kafka.listener.auto-startup=false"})
class AuditConsumerTest {
    @Autowired JdbcTemplate jdbc; @Autowired ApplicationAuditConsumer consumer; @Autowired ObjectMapper json;
    @MockitoBean JwtDecoder decoder;
    @BeforeEach void schema() {
        jdbc.execute("DROP ALL OBJECTS");
        new ResourceDatabasePopulator(new ClassPathResource("db/migration/V1__event_delivery_tables.sql"),new ClassPathResource("db/migration/V2__audit_events.sql")).execute(jdbc.getDataSource());
    }
    String event() { return """
        {"eventId":"22222222-2222-4222-8222-222222222222","applicationId":"33333333-3333-4333-8333-333333333333","eventType":"application.submitted","schemaVersion":"1.0","correlationId":"flow-104","producer":"application-service","occurredAt":"2026-10-13T09:30:00Z","aggregateVersion":1,"actor":{"type":"SYSTEM_CLIENT","subject":"marketplace","accessToken":"secret"},"data":{"status":"AWAITING_CONSENT","rawIdentityDocument":"secret"},"password":"secret"}
        """; }
    @Test void duplicateEventCreatesOneSafeAuditRecord() throws Exception {
        consumer.consume(event()); consumer.consume(event());
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM audit_event",Integer.class)).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM event_inbox",Integer.class)).isEqualTo(1);
        String safe=jdbc.queryForObject("SELECT safe_payload FROM audit_event",String.class);
        assertThat(safe).doesNotContain("secret","accessToken","rawIdentityDocument","password");
    }
    @Test void failedAuditWriteDoesNotMarkEventProcessed() {
        jdbc.execute("ALTER TABLE audit_event ADD CONSTRAINT force_failure CHECK(producer='impossible')");
        assertThatThrownBy(()->consumer.consume(event())).isInstanceOf(org.springframework.dao.DataIntegrityViolationException.class);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM event_inbox",Integer.class)).isZero();
    }
    @Test void malformedEventIsRejectedWithoutDatabaseChanges() {
        assertThatThrownBy(()->consumer.consume("{}" )).isInstanceOf(IllegalArgumentException.class);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM event_inbox",Integer.class)).isZero();
    }
}
