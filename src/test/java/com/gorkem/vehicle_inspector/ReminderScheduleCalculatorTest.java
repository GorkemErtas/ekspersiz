package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.dto.request.MaintenanceRequest;
import com.gorkem.vehicle_inspector.dto.request.ReminderRequest;
import com.gorkem.vehicle_inspector.entity.*;
import com.gorkem.vehicle_inspector.service.ReminderScheduleCalculator;
import org.junit.jupiter.api.Test;

import java.time.LocalDate;

import static org.junit.jupiter.api.Assertions.*;

class ReminderScheduleCalculatorTest {
    private final ReminderScheduleCalculator calculator = new ReminderScheduleCalculator();

    @Test
    void privateCarFirstAndRecurringInspectionsUseDifferentIntervals() {
        Vehicle vehicle = vehicle(VehicleCategory.PRIVATE_OR_OFFICIAL_CAR,
                LocalDate.of(2025, 4, 10));

        var first = calculator.calculate(vehicle, inspection(null, true));
        var recurring = calculator.calculate(vehicle,
                inspection(LocalDate.of(2028, 4, 12), false));

        assertEquals(LocalDate.of(2028, 4, 10), first.dueDate());
        assertEquals(LocalDate.of(2030, 4, 12), recurring.dueDate());
    }

    @Test
    void officialIntervalsAreAppliedPerVehicleCategory() {
        assertInspectionYears(VehicleCategory.WHEELED_TRACTOR, 3, 3);
        assertInspectionYears(VehicleCategory.TWO_OR_THREE_WHEELED, 3, 2);
        assertInspectionYears(VehicleCategory.OTHER_VEHICLE, 1, 1);
    }

    @Test
    void inspectionCanUseExplicitOfficialExpiryWhenCalculationInputsAreUnknown() {
        Vehicle vehicle = vehicle(null, null);
        ReminderRequest request = new ReminderRequest(ReminderType.VEHICLE_INSPECTION,
                null, LocalDate.of(2027, 5, 20), null, null);

        assertEquals(LocalDate.of(2027, 5, 20),
                calculator.calculate(vehicle, request).dueDate());
    }

    @Test
    void inspectionCalculationRejectsMissingCategoryInsteadOfGuessing() {
        Vehicle vehicle = vehicle(null, LocalDate.of(2025, 1, 1));

        assertThrows(IllegalArgumentException.class,
                () -> calculator.calculate(vehicle, inspection(null, true)));
    }

    @Test
    void trafficAndComprehensiveInsuranceUseExactPolicyExpiry() {
        LocalDate expiry = LocalDate.of(2027, 2, 15);
        for (ReminderType type : new ReminderType[]{ReminderType.TRAFFIC_INSURANCE,
                ReminderType.COMPREHENSIVE_INSURANCE}) {
            ReminderRequest request = new ReminderRequest(type, null, expiry, null, null);
            assertEquals(expiry, calculator.calculate(vehicle(null, null), request).dueDate());
        }
    }

    @Test
    void periodicMaintenanceUsesUserProvidedMonthAndMileageIntervals() {
        ReminderRequest request = new ReminderRequest(ReminderType.PERIODIC_MAINTENANCE,
                null, null, null, null, LocalDate.of(2026, 8, 31), 50_000,
                6, 10_000, null);

        var result = calculator.calculate(vehicle(null, null), request);

        assertEquals(LocalDate.of(2027, 2, 28), result.dueDate());
        assertEquals(60_000, result.dueMileage());
    }

    @Test
    void maintenanceRecordRecommendationsAreCalculatedFromServiceInputs() {
        MaintenanceRequest request = new MaintenanceRequest(
                MaintenanceType.PERIODIC_MAINTENANCE,
                LocalDate.of(2026, 9, 1), 50_000, null, null,
                null, null, 12, 15_000);

        var result = calculator.calculateMaintenance(request);

        assertEquals(LocalDate.of(2027, 9, 1), result.nextDate());
        assertEquals(65_000, result.nextMileage());
    }

    @Test
    void calculatedAndManualTargetsCannotCompeteAsSourcesOfTruth() {
        ReminderRequest request = new ReminderRequest(ReminderType.PERIODIC_MAINTENANCE,
                null, LocalDate.of(2027, 1, 1), null, null,
                LocalDate.of(2026, 1, 1), null, 12, null, null);

        assertThrows(IllegalArgumentException.class,
                () -> calculator.calculate(vehicle(null, null), request));
    }

    private void assertInspectionYears(VehicleCategory category, int firstYears,
                                       int recurringYears) {
        LocalDate origin = LocalDate.of(2025, 6, 1);
        Vehicle vehicle = vehicle(category, origin);
        assertEquals(origin.plusYears(firstYears),
                calculator.calculate(vehicle, inspection(null, true)).dueDate());
        assertEquals(origin.plusYears(recurringYears),
                calculator.calculate(vehicle, inspection(origin, false)).dueDate());
    }

    private ReminderRequest inspection(LocalDate sourceDate, boolean first) {
        return new ReminderRequest(ReminderType.VEHICLE_INSPECTION,
                null, null, null, null, sourceDate, null,
                null, null, first);
    }

    private Vehicle vehicle(VehicleCategory category, LocalDate conformityDate) {
        Vehicle vehicle = new Vehicle("35ABC123", "Honda", "Civic", 2025,
                55_000, org.mockito.Mockito.mock(User.class));
        vehicle.setVehicleCategory(category);
        vehicle.setConformityDate(conformityDate);
        return vehicle;
    }
}
