package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.dto.request.MaintenanceRequest;
import com.gorkem.vehicle_inspector.dto.request.ReminderRequest;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.service.ReminderScheduleCalculator;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.*;

class ReminderScheduleCalculatorTest {

    private final ReminderScheduleCalculator calculator =
            new ReminderScheduleCalculator();

    @Test
    void firstInspectionShouldScheduleNextInspectionThreeYearsLater() {
        LocalDate lastInspectionDate = LocalDate.of(2026, 5, 10);

        var result = calculator.calculate(
                vehicle(),
                inspection(lastInspectionDate, true)
        );

        assertEquals(
                LocalDate.of(2029, 5, 10),
                result.dueDate()
        );

        assertEquals(
                lastInspectionDate,
                result.sourceDate()
        );

        assertEquals(true, result.firstInspection());
    }

    @Test
    void recurringInspectionShouldScheduleNextInspectionTwoYearsLater() {
        LocalDate lastInspectionDate = LocalDate.of(2026, 5, 10);

        var result = calculator.calculate(
                vehicle(),
                inspection(lastInspectionDate, false)
        );

        assertEquals(
                LocalDate.of(2028, 5, 10),
                result.dueDate()
        );

        assertEquals(
                lastInspectionDate,
                result.sourceDate()
        );

        assertEquals(false, result.firstInspection());
    }

    @Test
    void firstInspectionRequiresLastInspectionDate() {
        ReminderRequest request = inspection(null, true);

        assertThrows(
                IllegalArgumentException.class,
                () -> calculator.calculate(vehicle(), request)
        );
    }

    @Test
    void inspectionCanUseExplicitDueDateForManualReminder() {
        LocalDate dueDate = LocalDate.of(2027, 5, 20);

        ReminderRequest request = new ReminderRequest(
                ReminderType.VEHICLE_INSPECTION,
                null,
                dueDate,
                null,
                null
        );

        assertEquals(
                dueDate,
                calculator.calculate(vehicle(), request).dueDate()
        );
    }

    @Test
    void inspectionRejectsManualAndSourceDateTogether() {
        ReminderRequest request = new ReminderRequest(
                ReminderType.VEHICLE_INSPECTION,
                null,
                LocalDate.of(2028, 5, 10),
                null,
                null,
                LocalDate.of(2026, 5, 10),
                null,
                null,
                null,
                false
        );

        assertThrows(
                IllegalArgumentException.class,
                () -> calculator.calculate(vehicle(), request)
        );
    }

    @Test
    void trafficAndComprehensiveInsuranceUseExactPolicyExpiry() {
        LocalDate expiry = LocalDate.of(2027, 2, 15);

        for (ReminderType type : new ReminderType[]{
                ReminderType.TRAFFIC_INSURANCE,
                ReminderType.COMPREHENSIVE_INSURANCE
        }) {
            ReminderRequest request = new ReminderRequest(
                    type,
                    null,
                    expiry,
                    null,
                    null
            );

            assertEquals(
                    expiry,
                    calculator.calculate(vehicle(), request).dueDate()
            );
        }
    }

    @Test
    void periodicMaintenanceUsesUserProvidedMonthAndMileageIntervals() {
        ReminderRequest request = new ReminderRequest(
                ReminderType.PERIODIC_MAINTENANCE,
                null,
                null,
                null,
                null,
                LocalDate.of(2026, 8, 31),
                50_000,
                6,
                10_000,
                null
        );

        var result = calculator.calculate(vehicle(), request);

        assertEquals(
                LocalDate.of(2027, 2, 28),
                result.dueDate()
        );

        assertEquals(
                60_000,
                result.dueMileage()
        );
    }

    @Test
    void maintenanceRecordRecommendationsAreCalculatedFromServiceInputs() {
        MaintenanceRequest request = new MaintenanceRequest(
                MaintenanceType.PERIODIC_MAINTENANCE,
                LocalDate.of(2026, 9, 1),
                50_000,
                null,
                null,
                null,
                null,
                12,
                15_000
        );

        var result = calculator.calculateMaintenance(request);

        assertEquals(
                LocalDate.of(2027, 9, 1),
                result.nextDate()
        );

        assertEquals(
                65_000,
                result.nextMileage()
        );
    }

    @Test
    void calculatedAndManualTargetsCannotCompeteAsSourcesOfTruth() {
        ReminderRequest request = new ReminderRequest(
                ReminderType.PERIODIC_MAINTENANCE,
                null,
                LocalDate.of(2027, 1, 1),
                null,
                null,
                LocalDate.of(2026, 1, 1),
                null,
                12,
                null,
                null
        );

        assertThrows(
                IllegalArgumentException.class,
                () -> calculator.calculate(vehicle(), request)
        );
    }

    private ReminderRequest inspection(
            LocalDate sourceDate,
            boolean first
    ) {
        return new ReminderRequest(
                ReminderType.VEHICLE_INSPECTION,
                null,
                null,
                null,
                null,
                sourceDate,
                null,
                null,
                null,
                first
        );
    }

    private Vehicle vehicle() {
        return new Vehicle(
                "35ABC123",
                "Honda",
                "Civic",
                2025,
                55_000,
                org.mockito.Mockito.mock(User.class)
        );
    }
}