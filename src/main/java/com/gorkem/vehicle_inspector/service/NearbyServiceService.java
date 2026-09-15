package com.gorkem.vehicle_inspector.service;

import com.gorkem.vehicle_inspector.client.GooglePlacesClient;
import com.gorkem.vehicle_inspector.dto.google.GooglePlacesTextSearchResponse;
import com.gorkem.vehicle_inspector.dto.llm.InspectionLlmRequest;
import com.gorkem.vehicle_inspector.dto.llm.NearbyServiceSearchResult;
import com.gorkem.vehicle_inspector.dto.response.NearbyServiceResponse;
import com.gorkem.vehicle_inspector.entity.DamageInspection;
import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.mapper.InspectionLlmMapper;
import com.gorkem.vehicle_inspector.service.report.GeminiNearbyServiceSearchService;

import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
public class NearbyServiceService {

    private static final double SEARCH_RADIUS_METERS =
            10_000;

    private static final int MAX_RESULTS =
            20;

    private final BusinessContextService businessContextService;
    private final InspectionAccessService inspectionAccessService;
    private final TransactionTemplate transactionTemplate;

    private final GeminiNearbyServiceSearchService
            geminiNearbyServiceSearchService;

    private final GooglePlacesClient
            googlePlacesClient;

    public NearbyServiceService(
            BusinessContextService businessContextService,
            InspectionAccessService inspectionAccessService,
            PlatformTransactionManager transactionManager,
            GeminiNearbyServiceSearchService
                    geminiNearbyServiceSearchService,
            GooglePlacesClient googlePlacesClient
    ) {
        this.businessContextService = businessContextService;
        this.inspectionAccessService = inspectionAccessService;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
        this.transactionTemplate.setReadOnly(true);

        this.geminiNearbyServiceSearchService =
                geminiNearbyServiceSearchService;

        this.googlePlacesClient =
                googlePlacesClient;
    }

    public List<NearbyServiceResponse> getNearbyServices(
            Long inspectionId,
            String userEmail
    ) {
        if (inspectionId == null) {
            throw new IllegalArgumentException(
                    "Inspection ID boş olamaz."
            );
        }

        NearbySearchContext context = transactionTemplate.execute(status -> {
            User user = businessContextService.requireUser(userEmail);
            DamageInspection inspection = inspectionAccessService.requireInspection(inspectionId, user);
            Double latitude = inspection.getLocationLatitude();
            Double longitude = inspection.getLocationLongitude();
            if (latitude == null || longitude == null) {
                throw new IllegalStateException("İncelemeye ait konum bilgisi bulunamadı.");
            }
            return new NearbySearchContext(
                    InspectionLlmMapper.toRequest(inspection), latitude, longitude);
        });
        if (context == null) {
            throw new IllegalStateException("Servis araması başlatılamadı.");
        }
        double latitude = context.latitude();
        double longitude = context.longitude();

        NearbyServiceSearchResult
                searchResult =
                geminiNearbyServiceSearchService
                        .generateSearchQueries(
                                context.request()
                        );

        Map<String, NearbyServiceResponse>
                uniquePlaces =
                new LinkedHashMap<>();

        for (String query
                : searchResult.searchQueries) {

            List<
                    GooglePlacesTextSearchResponse.Place
                    > places =
                    googlePlacesClient.search(
                            query,
                            latitude,
                            longitude,
                            SEARCH_RADIUS_METERS
                    );

            for (
                    GooglePlacesTextSearchResponse.Place
                            place : places
            ) {
                NearbyServiceResponse response =
                        toResponse(
                                place,
                                latitude,
                                longitude
                        );

                if (response == null) {
                    continue;
                }

                uniquePlaces.putIfAbsent(
                        response.placeId(),
                        response
                );
            }
        }

        List<NearbyServiceResponse> results =
                new ArrayList<>(
                        uniquePlaces.values()
                );

        results.sort(
                Comparator.comparing(
                        NearbyServiceResponse
                                ::distanceKm,
                        Comparator.nullsLast(
                                Comparator.naturalOrder()
                        )
                )
        );

        if (results.size() > MAX_RESULTS) {
            return results.subList(
                    0,
                    MAX_RESULTS
            );
        }

        return results;
    }

    private NearbyServiceResponse toResponse(
            GooglePlacesTextSearchResponse.Place place,
            double originLatitude,
            double originLongitude
    ) {
        if (place == null
                || place.id() == null
                || place.id().isBlank()
                || place.location() == null
                || place.location().latitude() == null
                || place.location().longitude() == null) {

            return null;
        }

        if (place.businessStatus() != null
                && !place.businessStatus()
                .equals("OPERATIONAL")) {

            return null;
        }

        String name =
                place.displayName() != null
                        ? place.displayName().text()
                        : null;

        double distanceKm =
                calculateDistanceKm(
                        originLatitude,
                        originLongitude,
                        place.location().latitude(),
                        place.location().longitude()
                );

        if (distanceKm
                > SEARCH_RADIUS_METERS / 1000.0) {

            return null;
        }

        return new NearbyServiceResponse(
                place.id(),
                name,
                place.formattedAddress(),
                place.location().latitude(),
                place.location().longitude(),
                place.rating(),
                place.userRatingCount(),
                place.primaryType(),
                place.googleMapsUri(),
                distanceKm
        );
    }

    private record NearbySearchContext(
            InspectionLlmRequest request,
            double latitude,
            double longitude
    ) {
    }

    private double calculateDistanceKm(
            double latitude1,
            double longitude1,
            double latitude2,
            double longitude2
    ) {
        final double earthRadiusKm =
                6371.0088;

        double latitudeDistance =
                Math.toRadians(
                        latitude2 - latitude1
                );

        double longitudeDistance =
                Math.toRadians(
                        longitude2 - longitude1
                );

        double a =
                Math.sin(
                        latitudeDistance / 2
                )
                        * Math.sin(
                        latitudeDistance / 2
                )
                        + Math.cos(
                        Math.toRadians(latitude1)
                )
                        * Math.cos(
                        Math.toRadians(latitude2)
                )
                        * Math.sin(
                        longitudeDistance / 2
                )
                        * Math.sin(
                        longitudeDistance / 2
                );

        double c =
                2 * Math.atan2(
                        Math.sqrt(a),
                        Math.sqrt(1 - a)
                );

        return earthRadiusKm * c;
    }
}
