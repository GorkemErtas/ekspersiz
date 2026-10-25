package com.gorkem.vehicle_inspector.service;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class DamageAnalysisRolloutPolicyTest {
    @Test
    void regularModeDoesNotAddNewRestrictions() {
        assertTrue(DamageInspectionService.analysisAccessAllowed(false, null, null));
        assertTrue(DamageInspectionService.analysisAccessAllowed(false, "", "user@example.com"));
    }

    @Test
    void testerOnlyModeFailsClosedWhenListIsMissingOrBlank() {
        assertFalse(DamageInspectionService.analysisAccessAllowed(true, null, "test@example.com"));
        assertFalse(DamageInspectionService.analysisAccessAllowed(true, "", "test@example.com"));
        assertFalse(DamageInspectionService.analysisAccessAllowed(true, "   ", "test@example.com"));
        assertFalse(DamageInspectionService.analysisAccessAllowed(true, "test@example.com", null));
        assertFalse(DamageInspectionService.analysisAccessAllowed(true, "test@example.com", ""));
    }

    @Test
    void permitsExactAuthenticatedEmailIgnoringOnlyWhitespaceAndCase() {
        assertTrue(DamageInspectionService.analysisAccessAllowed(true,
                "other@example.com, TEST@EXAMPLE.COM  ", "test@example.com"));
        assertTrue(DamageInspectionService.analysisAccessAllowed(true,
                "test@example.com", " TEST@EXAMPLE.COM "));
        assertFalse(DamageInspectionService.analysisAccessAllowed(true,
                "test@example.com", "attacker-test@example.com"));
        assertFalse(DamageInspectionService.analysisAccessAllowed(true,
                "test@example.com", "test@example.com.evil.org"));
        assertFalse(DamageInspectionService.analysisAccessAllowed(true,
                "test@example.com", "someoneelse@example.com"));
    }
}
