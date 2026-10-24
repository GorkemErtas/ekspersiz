package com.gorkem.vehicle_inspector.service;

import java.util.List;

/** Generated from the audited HITL catalog; preserves original names and IDs. */
public final class VisionClassCatalog {
    public record Entry(int id, String task, String code, String originalName, String turkishName) {}
    public static final List<Entry> CLASSES = List.of(
            new Entry(1, "damage", "BROKEN_PART", "Broken part", "Kırık parça"),
            new Entry(2, "damage", "CORROSION", "Corrosion", "Korozyon"),
            new Entry(3, "damage", "CRACKED", "Cracked", "Çatlak"),
            new Entry(4, "damage", "DENT", "Dent", "Göçük"),
            new Entry(5, "damage", "FLAKING", "Flaking", "Boya soyulması"),
            new Entry(6, "damage", "MISSING_PART", "Missing part", "Eksik parça"),
            new Entry(7, "damage", "PAINT_CHIP", "Paint chip", "Boya kopması"),
            new Entry(8, "damage", "SCRATCH", "Scratch", "Çizik"),
            new Entry(9, "part", "BACK_BUMPER", "Back-bumper", "Arka tampon"),
            new Entry(10, "part", "BACK_DOOR", "Back-door", "Arka kapı"),
            new Entry(11, "part", "BACK_WHEEL", "Back-wheel", "Arka tekerlek"),
            new Entry(12, "part", "BACK_WINDOW", "Back-window", "Arka kapı camı"),
            new Entry(13, "part", "BACK_WINDSHIELD", "Back-windshield", "Arka cam"),
            new Entry(14, "part", "FENDER", "Fender", "Çamurluk"),
            new Entry(15, "part", "FRONT_BUMPER", "Front-bumper", "Ön tampon"),
            new Entry(16, "part", "FRONT_DOOR", "Front-door", "Ön kapı"),
            new Entry(17, "part", "FRONT_WHEEL", "Front-wheel", "Ön tekerlek"),
            new Entry(18, "part", "FRONT_WINDOW", "Front-window", "Ön kapı camı"),
            new Entry(19, "part", "GRILLE", "Grille", "Izgara"),
            new Entry(20, "part", "HEADLIGHT", "Headlight", "Far"),
            new Entry(21, "part", "HOOD", "Hood", "Kaput"),
            new Entry(22, "part", "LICENSE_PLATE", "License-plate", "Plaka"),
            new Entry(23, "part", "MIRROR", "Mirror", "Ayna"),
            new Entry(24, "part", "QUARTER_PANEL", "Quarter-panel", "Arka yan panel"),
            new Entry(25, "part", "ROCKER_PANEL", "Rocker-panel", "Marşpiyel"),
            new Entry(26, "part", "ROOF", "Roof", "Tavan"),
            new Entry(27, "part", "TAIL_LIGHT", "Tail-light", "Stop lambası"),
            new Entry(28, "part", "TRUNK", "Trunk", "Bagaj kapağı"),
            new Entry(29, "part", "WINDSHIELD", "Windshield", "Ön cam"));
    private VisionClassCatalog() {}
    public static Entry byName(String name) {
        return CLASSES.stream().filter(c -> c.originalName().equals(name)).findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Unknown HITL class: " + name));
    }
    public static Entry byCode(String code) {
        return CLASSES.stream().filter(c -> c.code().equals(code)).findFirst()
                .orElseThrow(() -> new IllegalArgumentException("Unknown HITL code: " + code));
    }
}
