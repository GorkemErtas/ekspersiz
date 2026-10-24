-- Additive HITL contract: preserve every historical enum value and row.
ALTER TABLE damage_detections DROP CONSTRAINT IF EXISTS damage_detections_affected_part_check;
ALTER TABLE damage_detections ADD CONSTRAINT damage_detections_affected_part_check CHECK (affected_part IN ('UNKNOWN', 'FRONT_BUMPER', 'REAR_BUMPER', 'FRONT_DOOR', 'REAR_DOOR', 'FRONT_WHEEL', 'REAR_WHEEL', 'FRONT_WINDOW', 'REAR_WINDOW', 'WINDSHIELD', 'REAR_WINDSHIELD', 'FENDER', 'QUARTER_PANEL', 'ROCKER_PANEL', 'GRILLE', 'HEADLIGHT', 'TAIL_LIGHT', 'HOOD', 'LICENSE_PLATE', 'MIRROR', 'ROOF', 'TRUNK', 'BACK_BUMPER', 'BACK_DOOR', 'BACK_WHEEL', 'BACK_WINDOW', 'BACK_WINDSHIELD'));
ALTER TABLE damage_recommendation_parts DROP CONSTRAINT IF EXISTS damage_recommendation_parts_vehicle_part_check;
ALTER TABLE damage_recommendation_parts ADD CONSTRAINT damage_recommendation_parts_vehicle_part_check CHECK (vehicle_part IN ('UNKNOWN', 'FRONT_BUMPER', 'REAR_BUMPER', 'FRONT_DOOR', 'REAR_DOOR', 'FRONT_WHEEL', 'REAR_WHEEL', 'FRONT_WINDOW', 'REAR_WINDOW', 'WINDSHIELD', 'REAR_WINDSHIELD', 'FENDER', 'QUARTER_PANEL', 'ROCKER_PANEL', 'GRILLE', 'HEADLIGHT', 'TAIL_LIGHT', 'HOOD', 'LICENSE_PLATE', 'MIRROR', 'ROOF', 'TRUNK', 'BACK_BUMPER', 'BACK_DOOR', 'BACK_WHEEL', 'BACK_WINDOW', 'BACK_WINDSHIELD'));
ALTER TABLE damage_repair_recommendations DROP CONSTRAINT IF EXISTS damage_repair_recommendations_damage_type_check;
ALTER TABLE damage_repair_recommendations ADD CONSTRAINT damage_repair_recommendations_damage_type_check CHECK (damage_type IN ('NO_VISIBLE_DAMAGE', 'SCRATCH', 'PAINT_DAMAGE', 'DENT', 'CRACK', 'BROKEN_PART', 'BROKEN_GLASS', 'DEFORMATION', 'CORROSION', 'CRACKED', 'FLAKING', 'MISSING_PART', 'PAINT_CHIP'));
ALTER TABLE damage_repair_recommendations DROP CONSTRAINT IF EXISTS damage_repair_recommendations_recommended_action_check;
ALTER TABLE damage_repair_recommendations ADD CONSTRAINT damage_repair_recommendations_recommended_action_check CHECK (recommended_action IN ('NO_ACTION', 'POLISHING', 'PAINT_TOUCH_UP', 'FULL_PAINTING', 'PAINTLESS_DENT_REPAIR', 'DENT_REPAIR', 'PLASTIC_REPAIR', 'PART_REPAIR', 'PART_REPLACEMENT', 'GLASS_REPAIR', 'GLASS_REPLACEMENT', 'HEADLIGHT_REPAIR', 'HEADLIGHT_REPLACEMENT', 'PROFESSIONAL_INSPECTION'));
ALTER TABLE damage_inspections ADD COLUMN analysis_schema_version VARCHAR(40);
ALTER TABLE damage_inspections ADD COLUMN analysis_model_version VARCHAR(160);
ALTER TABLE damage_inspections ADD COLUMN analysis_payload TEXT;
ALTER TABLE damage_repair_recommendations ALTER COLUMN part_replacement_required DROP NOT NULL;
