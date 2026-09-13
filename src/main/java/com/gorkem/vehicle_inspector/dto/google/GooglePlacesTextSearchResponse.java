package com.gorkem.vehicle_inspector.dto.google;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

import java.util.List;

@JsonIgnoreProperties(ignoreUnknown = true)
public record GooglePlacesTextSearchResponse(
        List<Place> places
) {

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Place(

            String id,

            DisplayName displayName,

            String formattedAddress,

            Location location,

            Double rating,

            Integer userRatingCount,

            String businessStatus,

            String primaryType,

            String googleMapsUri

    ) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record DisplayName(
            String text,
            String languageCode
    ) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Location(
            Double latitude,
            Double longitude
    ) {
    }
}