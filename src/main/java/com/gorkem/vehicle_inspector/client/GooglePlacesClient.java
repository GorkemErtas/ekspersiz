package com.gorkem.vehicle_inspector.client;

import com.gorkem.vehicle_inspector.dto.google.GooglePlacesTextSearchResponse;

import org.springframework.beans.factory.annotation.Value;

import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;

import org.springframework.stereotype.Component;

import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.util.List;
import java.util.Map;

@Component
public class GooglePlacesClient {

    private static final String FIELD_MASK =
            "places.id,"
                    + "places.displayName,"
                    + "places.formattedAddress,"
                    + "places.location,"
                    + "places.rating,"
                    + "places.userRatingCount,"
                    + "places.businessStatus,"
                    + "places.primaryType,"
                    + "places.googleMapsUri";

    private final RestTemplate restTemplate;

    private final String apiKey;

    private final String baseUrl;

    public GooglePlacesClient(
            RestTemplate restTemplate,

            @Value("${application.google.places.api-key}")
            String apiKey,

            @Value("${application.google.places.base-url}")
            String baseUrl
    ) {
        this.restTemplate = restTemplate;

        this.apiKey =
                validateApiKey(apiKey);

        this.baseUrl =
                normalizeBaseUrl(baseUrl);
    }

    public List<GooglePlacesTextSearchResponse.Place>
    search(
            String query,
            double latitude,
            double longitude,
            double radiusMeters
    ) {
        if (query == null
                || query.isBlank()) {

            throw new IllegalArgumentException(
                    "Google Places arama sorgusu boş olamaz."
            );
        }

        validateCoordinates(
                latitude,
                longitude
        );

        if (radiusMeters <= 0
                || radiusMeters > 50_000) {

            throw new IllegalArgumentException(
                    "Arama yarıçapı 0 ile 50.000 metre arasında olmalıdır."
            );
        }

        Map<String, Object> center =
                Map.of(
                        "latitude",
                        latitude,

                        "longitude",
                        longitude
                );

        Map<String, Object> circle =
                Map.of(
                        "center",
                        center,

                        "radius",
                        radiusMeters
                );

        Map<String, Object> locationBias =
                Map.of(
                        "circle",
                        circle
                );

        Map<String, Object> requestBody =
                Map.of(
                        "textQuery",
                        query.trim(),

                        "locationBias",
                        locationBias,

                        "languageCode",
                        "tr",

                        "regionCode",
                        "TR",

                        "rankPreference",
                        "RELEVANCE",

                        "pageSize",
                        10
                );

        HttpHeaders headers =
                new HttpHeaders();

        headers.setContentType(
                MediaType.APPLICATION_JSON
        );

        headers.set(
                "X-Goog-Api-Key",
                apiKey
        );

        headers.set(
                "X-Goog-FieldMask",
                FIELD_MASK
        );

        HttpEntity<Map<String, Object>> request =
                new HttpEntity<>(
                        requestBody,
                        headers
                );

        try {

            ResponseEntity<GooglePlacesTextSearchResponse>
                    response =
                    restTemplate.exchange(
                            baseUrl
                                    + "/v1/places:searchText",

                            HttpMethod.POST,

                            request,

                            GooglePlacesTextSearchResponse.class
                    );

            GooglePlacesTextSearchResponse body =
                    response.getBody();

            if (body == null
                    || body.places() == null) {

                return List.of();
            }

            return body.places();

        } catch (ResourceAccessException exception) {

            throw new IllegalStateException(
                    "Google Places servisine ulaşılamadı.",
                    exception
            );

        } catch (HttpStatusCodeException exception) {

            throw new IllegalStateException(
                    "Google Places servisi hata döndürdü. HTTP "
                            + exception
                            .getStatusCode()
                            .value(),
                    exception
            );

        } catch (RestClientException exception) {

            throw new IllegalStateException(
                    "Google Places servisi ile iletişim sırasında hata oluştu.",
                    exception
            );
        }
    }

    private static void validateCoordinates(
            double latitude,
            double longitude
    ) {
        if (latitude < -90
                || latitude > 90) {

            throw new IllegalArgumentException(
                    "Geçersiz latitude değeri."
            );
        }

        if (longitude < -180
                || longitude > 180) {

            throw new IllegalArgumentException(
                    "Geçersiz longitude değeri."
            );
        }
    }

    private static String validateApiKey(
            String apiKey
    ) {
        if (apiKey == null
                || apiKey.isBlank()) {

            throw new IllegalArgumentException(
                    "Google Places API key tanımlı değil."
            );
        }

        return apiKey.trim();
    }

    private static String normalizeBaseUrl(
            String baseUrl
    ) {
        if (baseUrl == null
                || baseUrl.isBlank()) {

            throw new IllegalArgumentException(
                    "Google Places base URL boş olamaz."
            );
        }

        String normalized =
                baseUrl.trim();

        while (normalized.endsWith("/")) {
            normalized =
                    normalized.substring(
                            0,
                            normalized.length() - 1
                    );
        }

        return normalized;
    }
}