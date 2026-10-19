package com.gorkem.vehicle_inspector.service.billing;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.List;

/** Reference TRY prices. The store remains authoritative for checkout. */
public final class CreditCatalog {
    private CreditCatalog() {}
    public static final BigDecimal BUSINESS_PRICE = new BigDecimal("4999.99");
    public record Product(String productId, String resource, int quantity, int discountPercent,
                          BigDecimal referencePrice, BigDecimal unitPrice, BigDecimal savings,
                          String currency, boolean business) {}

    public static List<Product> products() {
        List<Product> result = new ArrayList<>();
        for (boolean business : List.of(false, true)) {
            for (String resource : List.of("ANALYSIS", "ASSISTANT", "SLOT")) {
                int[] quantities = resource.equals("SLOT") ? new int[]{1} : new int[]{1, 5, 10, 20, 50};
                BigDecimal single = new BigDecimal(switch (resource) {
                    case "ANALYSIS" -> "39.99";
                    case "ASSISTANT" -> "9.99";
                    default -> "4.99";
                });
                for (int quantity : quantities) {
                    int discount = switch (quantity) { case 5 -> 5; case 10 -> 10; case 20 -> 20; case 50 -> 25; default -> 0; };
                    BigDecimal regular = single.multiply(BigDecimal.valueOf(quantity));
                    BigDecimal price = regular.multiply(BigDecimal.valueOf(100 - discount))
                            .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP);
                    result.add(new Product("eksper_" + resource.toLowerCase(java.util.Locale.ROOT) + "_" + quantity
                            + (business ? "_business" : ""), resource, quantity, discount, price,
                            price.divide(BigDecimal.valueOf(quantity), 2, RoundingMode.HALF_UP),
                            regular.subtract(price), "TRY", business));
                }
            }
        }
        return List.copyOf(result);
    }

    public static Product find(String id) {
        return products().stream().filter(p -> p.productId().equals(id)).findFirst().orElse(null);
    }
}
