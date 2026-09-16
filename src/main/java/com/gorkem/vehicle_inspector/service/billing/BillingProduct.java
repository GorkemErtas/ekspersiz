package com.gorkem.vehicle_inspector.service.billing;

import com.gorkem.vehicle_inspector.entity.SubscriptionPlan;

import java.math.BigDecimal;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;

public enum BillingProduct {
    PLUS(
            SubscriptionPlan.PLUS,
            "Plus",
            "Bireysel kullanıcılar için daha geniş kullanım",
            "eksper_plus_monthly",
            "plus_monthly",
            new BigDecimal("149.99"),
            false,
            List.of("5 aktif araç", "Günde 15 hasar analizi")
    ),
    PRO(
            SubscriptionPlan.PRO,
            "Pro",
            "Yoğun bireysel kullanım için limitsiz plan",
            "eksper_pro_monthly",
            "pro_monthly",
            new BigDecimal("349.99"),
            true,
            List.of("Sınırsız aktif araç", "Sınırsız hasar analizi")
    ),
    BUSINESS(
            SubscriptionPlan.BUSINESS,
            "Business",
            "Ekipler ve ortak şirket araçları için",
            "eksper_business_monthly",
            "business_monthly",
            new BigDecimal("1499.99"),
            false,
            List.of(
                    "50 ortak aktif araç",
                    "Şirket genelinde günde 100 analiz",
                    "Çalışan daveti ve ortak geçmiş"
            )
    );

    private final SubscriptionPlan plan;
    private final String title;
    private final String description;
    private final String productId;
    private final String packageIdentifier;
    private final BigDecimal fallbackMonthlyPrice;
    private final boolean highlighted;
    private final List<String> features;

    BillingProduct(
            SubscriptionPlan plan,
            String title,
            String description,
            String productId,
            String packageIdentifier,
            BigDecimal fallbackMonthlyPrice,
            boolean highlighted,
            List<String> features
    ) {
        this.plan = plan;
        this.title = title;
        this.description = description;
        this.productId = productId;
        this.packageIdentifier = packageIdentifier;
        this.fallbackMonthlyPrice = fallbackMonthlyPrice;
        this.highlighted = highlighted;
        this.features = features;
    }

    public static Optional<BillingProduct> fromProductId(String productId) {
        if (productId == null) {
            return Optional.empty();
        }

        return Arrays.stream(values())
                .filter(product ->
                        product.productId.equals(productId)
                                || productId.startsWith(product.productId + ":")
                )
                .findFirst();
    }

    public SubscriptionPlan getPlan() {
        return plan;
    }

    public String getTitle() {
        return title;
    }

    public String getDescription() {
        return description;
    }

    public String getProductId() {
        return productId;
    }

    public String getPackageIdentifier() {
        return packageIdentifier;
    }

    public BigDecimal getFallbackMonthlyPrice() {
        return fallbackMonthlyPrice;
    }

    public boolean isHighlighted() {
        return highlighted;
    }

    public List<String> getFeatures() {
        return features;
    }
}
