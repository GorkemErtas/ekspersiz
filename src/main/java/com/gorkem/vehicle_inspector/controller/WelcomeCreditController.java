package com.gorkem.vehicle_inspector.controller;
import com.gorkem.vehicle_inspector.service.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController
@RequestMapping("/api/v1/credits/welcome")
public class WelcomeCreditController {
    private final WelcomeCreditService welcome;
    private final BusinessContextService context;
    public WelcomeCreditController(WelcomeCreditService welcome,BusinessContextService context) {this.welcome=welcome;this.context=context;}
    public record Challenge(@NotBlank @Size(max=64) String deviceId) {}
    public record Claim(@NotNull UUID challengeId,@NotBlank @Size(max=20000) String token) {}
    @PostMapping("/challenge")
    public Map<String,Object> challenge(@Valid @RequestBody Challenge request,Authentication auth) {return welcome.challenge(context.requireUser(auth.getName()),request.deviceId());}
    @PostMapping("/claim")
    public Map<String,Boolean> claim(@Valid @RequestBody Claim request,Authentication auth) {
        welcome.claim(context.requireUser(auth.getName()),request.challengeId(),request.token());return Map.of("verified",true);
    }
}
