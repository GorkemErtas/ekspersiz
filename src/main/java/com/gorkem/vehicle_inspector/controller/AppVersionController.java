package com.gorkem.vehicle_inspector.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/app")
public class AppVersionController {

    private final int minimumAndroidBuild;

    public AppVersionController(
            @Value("${application.mobile.minimum-android-build:1}") int minimumAndroidBuild
    ) {
        this.minimumAndroidBuild = minimumAndroidBuild;
    }

    @GetMapping("/version")
    public AppVersionResponse getVersion() {
        return new AppVersionResponse(minimumAndroidBuild);
    }

    public record AppVersionResponse(int minimumAndroidBuild) {
    }
}
