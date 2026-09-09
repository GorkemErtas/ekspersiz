package com.gorkem.vehicle_inspector.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.web.client.RestTemplate;

import java.time.Duration;

@Configuration
public class RestTemplateConfig {

    @Bean
    public RestTemplate restTemplate(
            @Value(
                    "${application.http.connect-timeout-seconds:5}"
            )
            long connectTimeoutSeconds,
            @Value(
                    "${application.http.read-timeout-seconds:60}"
            )
            long readTimeoutSeconds
    ) {
        SimpleClientHttpRequestFactory requestFactory =
                new SimpleClientHttpRequestFactory();

        requestFactory.setConnectTimeout(
                Duration.ofSeconds(connectTimeoutSeconds)
        );

        requestFactory.setReadTimeout(
                Duration.ofSeconds(readTimeoutSeconds)
        );

        return new RestTemplate(requestFactory);
    }
}