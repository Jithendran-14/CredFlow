package com.credflow.platform;

import java.nio.file.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.yaml.snakeyaml.Yaml;
import com.fasterxml.jackson.databind.ObjectMapper;
import static org.assertj.core.api.Assertions.assertThat;

class InfrastructureConfigurationTest {
    private final Path root=Path.of("../..").toAbsolutePath().normalize();
    @Test void allYamlAndJsonConfigurationParses() throws Exception {
        try(var files=Files.walk(root)) {
            for(Path file:files.filter(Files::isRegularFile).filter(p->!p.toString().contains("target")&&!p.toString().contains(".git"+java.io.File.separator)).toList()) {
                if(file.toString().endsWith(".yml")) new Yaml().load(Files.readString(file));
                if(file.toString().endsWith(".json")) new ObjectMapper().readTree(Files.readString(file));
            }
        }
    }
    @Test void composeDefinesEightAppsAndRequiredInfrastructure() throws Exception {
        Map<?,?> compose=new Yaml().load(Files.readString(root.resolve("infrastructure/compose.yml")));
        Map<?,?> services=(Map<?,?>)compose.get("services");
        assertThat(services.size()).isEqualTo(12);
        long apps=services.values().stream().map(v->(Map<?,?>)v).filter(v->v.containsKey("profiles")).count();
        assertThat(apps).isEqualTo(8);
        for(String service:List.of("oracle","kafka","keycloak","kafka-init")) assertThat(services.containsKey(service)).isTrue();
    }
    @Test void realmHasNineHumanUsersAndDistinctClientIdentities() throws Exception {
        var realm=new ObjectMapper().readTree(Files.readString(root.resolve("infrastructure/keycloak/credflow-realm.json")));
        int humans=0;
        Set<String> clients=new HashSet<>();
        for(var user:realm.path("users")) if(!user.has("serviceAccountClientId")) humans++;
        for(var client:realm.path("clients")) {
            assertThat(clients.add(client.path("clientId").asText())).isTrue();
            assertThat(client.path("directAccessGrantsEnabled").asBoolean()).isFalse();
        }
        assertThat(humans).isEqualTo(9);
        assertThat(clients).contains("mock-marketplace-client","mock-bank-a-client","mock-nbfc-b-client");
    }
}
