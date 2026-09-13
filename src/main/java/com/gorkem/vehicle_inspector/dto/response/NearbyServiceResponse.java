package com.gorkem.vehicle_inspector.dto.response;

public record NearbyServiceResponse(

        String placeId,

        String name,

        String address,

        Double latitude,

        Double longitude,

        Double rating,

        Integer userRatingCount,

        String primaryType,

        String googleMapsUri,

        Double distanceKm

) {
}