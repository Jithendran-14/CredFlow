package com.credflow.application;
import java.math.BigDecimal;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import com.fasterxml.jackson.databind.ObjectMapper;
import static org.assertj.core.api.Assertions.*;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
@SpringBootTest(properties={"spring.datasource.url=jdbc:h2:mem:submission;MODE=Oracle;DB_CLOSE_DELAY=-1","spring.datasource.driver-class-name=org.h2.Driver","spring.datasource.username=sa","spring.datasource.password=","spring.flyway.enabled=false","spring.jpa.hibernate.ddl-auto=none","credflow.outbox.enabled=false"})
@AutoConfigureMockMvc
class ApplicationSubmissionTest {
    static final String MARKET="11111111-1111-4111-8111-111111111111";
    @Autowired MockMvc mvc; @Autowired JdbcTemplate jdbc; @Autowired ObjectMapper json;
    @Autowired ApplicationSubmissionService service;
    @MockitoBean JwtDecoder decoder;
    @BeforeEach void seed() {
        jdbc.execute("DROP ALL OBJECTS");
        new ResourceDatabasePopulator(new ClassPathResource("db/migration/V1__event_delivery_tables.sql"),new ClassPathResource("db/migration/V2__application_submission.sql")).execute(jdbc.getDataSource());
        jdbc.update("INSERT INTO seller_profile VALUES(?,?,?,?)","44444444-4444-4444-8444-000000000104",MARKET,"SELLER-104","seller104-subject");
    }
    ApplicationRequest request(String amount) {
        return new ApplicationRequest(UUID.fromString(MARKET),"SELLER-104","REQ-104-001",amount,ApplicationRequest.Currency.INR,ApplicationRequest.LoanPurpose.WORKING_CAPITAL,
            new ApplicationRequest.BusinessProfile("Aisha","Aisha Clothing",LocalDate.of(2024,1,1)),"SELLER-REQUEST-104-001",
            new ApplicationRequest.InitialSharingConsent("APPLICATION_SHARE_WITH_CREDFLOW","1.0",Instant.parse("2026-01-01T00:00:00Z"),"evidence-104"));
    }
    org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.JwtRequestPostProcessor marketplace() {
        return jwt().jwt(j->j.subject("marketplace-client").claim("organisationId",MARKET).claim("clientId","mock-marketplace-client")).authorities(new SimpleGrantedAuthority("ROLE_MARKETPLACE_CLIENT"));
    }
    @Test void creationAndEventCommitTogetherAndReplayDoesNotDuplicate() throws Exception {
        String body=json.writeValueAsString(request("500000.00"));
        String response=mvc.perform(post("/api/v1/applications").with(marketplace()).header("Idempotency-Key","same-key").header("X-Correlation-ID","flow-104").contentType("application/json").content(body))
            .andExpect(status().isCreated()).andExpect(jsonPath("$.status").value("AWAITING_CONSENT")).andReturn().getResponse().getContentAsString();
        String id=json.readTree(response).path("applicationId").asText();
        mvc.perform(post("/api/v1/applications").with(marketplace()).header("Idempotency-Key","same-key").contentType("application/json").content(body)).andExpect(status().isCreated()).andExpect(jsonPath("$.applicationId").value(id));
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM loan_application",Integer.class)).isEqualTo(1);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM event_outbox",Integer.class)).isEqualTo(1);
        var event=json.readTree(jdbc.queryForObject("SELECT payload FROM event_outbox",String.class));
        assertThat(event.path("correlationId").asText()).isEqualTo("flow-104");
        assertThat(event.path("actor").path("type").asText()).isEqualTo("SYSTEM_CLIENT");
        assertThat(event.has("businessProfile")).isFalse();
    }
    @Test void reusedKeyWithDifferentPayloadConflicts() throws Exception {
        mvc.perform(post("/api/v1/applications").with(marketplace()).header("Idempotency-Key","key").contentType("application/json").content(json.writeValueAsString(request("500000.00")))).andExpect(status().isCreated());
        mvc.perform(post("/api/v1/applications").with(marketplace()).header("Idempotency-Key","key").contentType("application/json").content(json.writeValueAsString(request("400000.00")))).andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("IDEMPOTENCY_CONFLICT"));
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM event_outbox",Integer.class)).isEqualTo(1);
    }
    @Test void anotherKeyCannotCreateSecondActiveApplication() throws Exception {
        String body=json.writeValueAsString(request("500000.00"));
        mvc.perform(post("/api/v1/applications").with(marketplace()).header("Idempotency-Key","key1").contentType("application/json").content(body)).andExpect(status().isCreated());
        mvc.perform(post("/api/v1/applications").with(marketplace()).header("Idempotency-Key","key2").contentType("application/json").content(body)).andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("APPLICATION_ALREADY_ACTIVE"));
    }
    @Test void callerCannotSpoofMarketplace() throws Exception {
        mvc.perform(post("/api/v1/applications").with(jwt().jwt(j->j.claim("organisationId","another-marketplace")).authorities(new SimpleGrantedAuthority("ROLE_MARKETPLACE_CLIENT"))).header("Idempotency-Key","key").contentType("application/json").content(json.writeValueAsString(request("500000.00")))).andExpect(status().isForbidden());
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM loan_application",Integer.class)).isZero();
    }
    @Test void sellerCannotSubmitAsMarketplace() throws Exception {
        mvc.perform(post("/api/v1/applications").with(jwt().authorities(new SimpleGrantedAuthority("ROLE_SELLER"))).header("Idempotency-Key","key").contentType("application/json").content(json.writeValueAsString(request("500000.00")))).andExpect(status().isForbidden());
    }
    @Test void differentSellerCannotReadApplication() throws Exception {
        var result=service.submit(request("500000.00"),"key",machineJwt(),"flow");
        mvc.perform(get("/api/v1/applications/"+result.applicationId()).with(jwt().jwt(j->j.subject("other-seller")).authorities(new SimpleGrantedAuthority("ROLE_SELLER")))).andExpect(status().isNotFound());
        mvc.perform(get("/api/v1/applications/"+result.applicationId()).with(jwt().jwt(j->j.subject("seller104-subject")).authorities(new SimpleGrantedAuthority("ROLE_SELLER")))).andExpect(status().isOk());
    }
    @Test void moneyFormatAndConsentAreRequired() throws Exception {
        mvc.perform(post("/api/v1/applications").with(marketplace()).header("Idempotency-Key","key").contentType("application/json").content(json.writeValueAsString(request("500000")))).andExpect(status().isBadRequest());
        var tree=json.valueToTree(request("500000.00")); ((com.fasterxml.jackson.databind.node.ObjectNode)tree).remove("initialSharingConsent");
        mvc.perform(post("/api/v1/applications").with(marketplace()).header("Idempotency-Key","key").contentType("application/json").content(json.writeValueAsString(tree))).andExpect(status().isBadRequest());
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM event_outbox",Integer.class)).isZero();
    }
    @Test void databaseFailureRollsBackApplicationAndIdempotency() {
        jdbc.execute("ALTER TABLE event_outbox ADD CONSTRAINT force_failure CHECK(event_type='impossible')");
        assertThatThrownBy(()->service.submit(request("500000.00"),"key",machineJwt(),"flow")).isInstanceOf(org.springframework.dao.DataIntegrityViolationException.class);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM loan_application",Integer.class)).isZero();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM api_idempotency",Integer.class)).isZero();
    }
    @Test void concurrentRequestsForSameSellerProduceOneApplication() throws Exception {
        try(var pool=java.util.concurrent.Executors.newFixedThreadPool(2)) {
            var tasks=List.<java.util.concurrent.Callable<ApplicationView>>of(()->service.submit(request("500000.00"),"key",machineJwt(),"flow"),()->service.submit(request("500000.00"),"key",machineJwt(),"flow"));
            var results=pool.invokeAll(tasks);
            assertThat(results.get(0).get().applicationId()).isEqualTo(results.get(1).get().applicationId());
        }
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM event_outbox",Integer.class)).isEqualTo(1);
    }
    Jwt machineJwt() { return Jwt.withTokenValue("test").header("alg","RS256").subject("marketplace-client").claim("organisationId",MARKET).claim("clientId","mock-marketplace-client").build(); }
}
