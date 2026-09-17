package com.gorkem.vehicle_inspector.entity;

public enum VehicleCategory {
    PRIVATE_OR_OFFICIAL_CAR(3, 2),
    WHEELED_TRACTOR(3, 3),
    TWO_OR_THREE_WHEELED(3, 2),
    OTHER_VEHICLE(1, 1);

    private final int firstInspectionYears;
    private final int recurringInspectionYears;

    VehicleCategory(int firstInspectionYears, int recurringInspectionYears) {
        this.firstInspectionYears = firstInspectionYears;
        this.recurringInspectionYears = recurringInspectionYears;
    }

    public int getFirstInspectionYears() { return firstInspectionYears; }
    public int getRecurringInspectionYears() { return recurringInspectionYears; }
}
