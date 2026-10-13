package com.credflow.integration;
import com.credflow.platform.PlatformConfiguration;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Import;
@SpringBootApplication @Import(PlatformConfiguration.class)
public class LenderIntegrationServiceApplication {
    public static void main(String[] args) { SpringApplication.run(LenderIntegrationServiceApplication.class,args); }
}
