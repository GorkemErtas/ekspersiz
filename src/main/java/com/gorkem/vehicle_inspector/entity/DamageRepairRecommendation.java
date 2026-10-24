package com.gorkem.vehicle_inspector.entity;

import jakarta.persistence.*;

import java.util.LinkedHashSet;
import java.util.Set;

@Entity
@Table(name = "damage_repair_recommendations")
public class DamageRepairRecommendation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(
            fetch = FetchType.LAZY,
            optional = false
    )
    @JoinColumn(
            name = "inspection_id",
            nullable = false,
            foreignKey = @ForeignKey(
                    name = "fk_recommendation_inspection"
            )
    )
    private DamageInspection inspection;

    @Enumerated(EnumType.STRING)
    @Column(
            name = "damage_type",
            nullable = false,
            length = 50
    )
    private DamageType damageType;

    @Enumerated(EnumType.STRING)
    @Column(
            name = "recommended_action",
            nullable = false,
            length = 50
    )
    private RepairAction recommendedAction;

    @Column(
            name = "part_replacement_required"
    )
    private Boolean partReplacementRequired;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(
            name = "damage_recommendation_parts",
            joinColumns = @JoinColumn(
                    name = "recommendation_id",
                    foreignKey = @ForeignKey(
                            name = "fk_recommendation_part"
                    )
            )
    )
    @Enumerated(EnumType.STRING)
    @Column(
            name = "vehicle_part",
            nullable = false,
            length = 50
    )
    private Set<VehiclePart> affectedParts =
            new LinkedHashSet<>();

    protected DamageRepairRecommendation() {
    }

    public DamageRepairRecommendation(
            DamageInspection inspection,
            DamageType damageType,
            RepairAction recommendedAction,
            Boolean partReplacementRequired,
            Set<VehiclePart> affectedParts
    ) {
        this.inspection = inspection;
        this.damageType = damageType;
        this.recommendedAction = recommendedAction;
        this.partReplacementRequired =
                partReplacementRequired;

        if (affectedParts != null) {
            this.affectedParts.addAll(affectedParts);
        }
    }

    public Long getId() {
        return id;
    }

    public DamageInspection getInspection() {
        return inspection;
    }

    public DamageType getDamageType() {
        return damageType;
    }

    public RepairAction getRecommendedAction() {
        return recommendedAction;
    }

    public Boolean getPartReplacementRequired() {
        return partReplacementRequired;
    }

    public Set<VehiclePart> getAffectedParts() {
        return affectedParts;
    }

    public void setInspection(
            DamageInspection inspection
    ) {
        this.inspection = inspection;
    }
}
