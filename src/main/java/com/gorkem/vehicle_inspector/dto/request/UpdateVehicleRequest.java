package com.gorkem.vehicle_inspector.dto.request;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import com.gorkem.vehicle_inspector.entity.VehicleCategory;
import java.time.LocalDate;

public class UpdateVehicleRequest {

    @NotBlank(message = "Plaka boş bırakılamaz.")
    @Size(max = 20, message = "Plaka en fazla 20 karakter olabilir.")
    @Pattern(
            regexp = "^[0-9]{2}[A-Z]{1,3}[0-9]{2,4}$",
            message = "Plaka geçerli formatta olmalıdır. Örnek: 35ABC123"
    )
    private String plate;

    @NotBlank(message = "Marka boş bırakılamaz.")
    @Size(max = 50, message = "Marka en fazla 50 karakter olabilir.")
    private String brand;

    @NotBlank(message = "Model boş bırakılamaz.")
    @Size(max = 50, message = "Model en fazla 50 karakter olabilir.")
    private String model;

    @NotNull(message = "Model yılı boş bırakılamaz.")
    @Min(value = 1950, message = "Model yılı 1950 veya daha büyük olmalıdır.")
    @Max(value = 2030, message = "Model yılı 2030 veya daha küçük olmalıdır.")
    private Integer modelYear;

    @NotNull(message = "Kilometre boş bırakılamaz.")
    @Min(value = 0, message = "Kilometre negatif olamaz.")
    @Max(value = 2_000_000, message = "Kilometre değeri çok yüksek.")
    private Integer mileage;

    private VehicleCategory vehicleCategory;

    private LocalDate conformityDate;

    @Size(max = 1000, message = "Notlar en fazla 1000 karakter olabilir.")
    private String notes;

    public String getPlate() {
        return plate;
    }

    public void setPlate(String plate) {
        this.plate = plate;
    }

    public String getBrand() {
        return brand;
    }

    public void setBrand(String brand) {
        this.brand = brand;
    }

    public String getModel() {
        return model;
    }

    public void setModel(String model) {
        this.model = model;
    }

    public Integer getModelYear() {
        return modelYear;
    }

    public void setModelYear(Integer modelYear) {
        this.modelYear = modelYear;
    }

    public Integer getMileage() {
        return mileage;
    }

    public void setMileage(Integer mileage) {
        this.mileage = mileage;
    }

    public String getNotes() { return notes; }
    public void setNotes(String notes) { this.notes = notes; }
    public VehicleCategory getVehicleCategory() { return vehicleCategory; }
    public void setVehicleCategory(VehicleCategory vehicleCategory) { this.vehicleCategory = vehicleCategory; }
    public LocalDate getConformityDate() { return conformityDate; }
    public void setConformityDate(LocalDate conformityDate) { this.conformityDate = conformityDate; }
}
