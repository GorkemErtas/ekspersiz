package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.VehiclePart;

public class DetectedObjectResponse {
    private Integer classId;
    private String code;
    private String task;


    private String label;
    private Double confidence;
    private VehiclePart affectedPart;
    private BoundingBoxResponse boundingBox;

    public DetectedObjectResponse() {
    }

    public String getLabel() {
        return label;
    }

    public void setLabel(String label) {
        this.label = label;
    }

    public Double getConfidence() {
        return confidence;
    }

    public void setConfidence(Double confidence) {
        this.confidence = confidence;
    }

    public VehiclePart getAffectedPart() {
        return affectedPart;
    }

    public void setAffectedPart(
            VehiclePart affectedPart
    ) {
        this.affectedPart = affectedPart;
    }

    public BoundingBoxResponse getBoundingBox() {
        return boundingBox;
    }

    public void setBoundingBox(
            BoundingBoxResponse boundingBox
    ) {
        this.boundingBox = boundingBox;
    }

    public Integer getClassId() { return classId; }
    public void setClassId(Integer value) { this.classId = value; }
    public String getCode() { return code; }
    public void setCode(String value) { this.code = value; }
    public String getTask() { return task; }
    public void setTask(String value) { this.task = value; }
}
