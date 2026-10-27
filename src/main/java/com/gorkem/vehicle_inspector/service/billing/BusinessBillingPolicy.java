package com.gorkem.vehicle_inspector.service.billing;

import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.exception.WorkspaceAccessDeniedException;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.LocalDateTime;

/** Local, server-owned authorization. Never calls RevenueCat or trusts client flags. */
@Component
public class BusinessBillingPolicy {
    public static final int SANDBOX_ANALYSES = 3;
    public static final int SANDBOX_ASSISTANT = 10;

    private final JdbcTemplate jdbc;
    private final BillingSandboxPolicy testers;
    private final Clock clock;

    public BusinessBillingPolicy(JdbcTemplate jdbc, BillingSandboxPolicy testers, Clock clock) {
        this.jdbc = jdbc;
        this.testers = testers;
        this.clock = clock;
    }

    public boolean sandboxSubscription(User user) {
        return Boolean.TRUE.equals(jdbc.queryForObject(
                "SELECT EXISTS(SELECT 1 FROM billing_subscriptions WHERE user_id=? AND sandbox)",
                Boolean.class, user.getId()));
    }

    public boolean allowsSandboxSubscription(User user) {
        // A sandbox receipt must never activate an existing real company, even if its owner is a tester.
        return testers.allows(user) && !Boolean.TRUE.equals(jdbc.queryForObject("""
                SELECT EXISTS(SELECT 1 FROM business_members m JOIN business_accounts b ON b.id=m.business_account_id
                WHERE m.user_id=? AND NOT b.sandbox)
                """, Boolean.class, user.getId()));
    }

    public boolean sandboxCompany(long businessId) {
        return Boolean.TRUE.equals(jdbc.queryForObject(
                "SELECT sandbox FROM business_accounts WHERE id=?", Boolean.class, businessId));
    }

    public void requireCompanyAccess(User actor, long businessId) {
        if (!allowsCompanyAccess(actor, businessId)) throw new WorkspaceAccessDeniedException();
    }

    public boolean allowsCompanyAccess(User actor, long businessId) {
        return allowsAccess(actor, company(businessId));
    }

    private boolean allowsAccess(User actor, Company company) {
        return company.sandbox()
                ? testers.allows(actor) && company.sandboxEntitlement() && company.active()
                    && testers.allowsCustomerId(company.customerId())
                : !company.sandboxEntitlement();
    }

    public void requireActiveCompany(User actor, long businessId) {
        var company = company(businessId);
        if (!allowsAccess(actor, company)) throw new WorkspaceAccessDeniedException();
        if (!company.active()) throw new IllegalStateException("Şirket aboneliği aktif değil.");
    }

    public void requireInvitation(User owner, User invited, long businessId) {
        requireActiveCompany(owner, businessId);
        if (sandboxCompany(businessId) && !testers.allows(invited)) {
            throw new IllegalStateException("Test şirketine yalnızca sunucuda yetkilendirilmiş test hesapları katılabilir.");
        }
    }

    public boolean companyEntitlementActive(long businessId) {
        var company = company(businessId);
        return company.active() && (company.sandbox()
                ? company.sandboxEntitlement() && testers.allowsCustomerId(company.customerId())
                : !company.sandboxEntitlement());
    }

    private Company company(long businessId) {
        var rows = jdbc.queryForList("""
                SELECT b.sandbox, u.billing_customer_id, u.subscription_plan, u.subscription_expires_at,
                       COALESCE(s.sandbox,FALSE) AS sandbox_entitlement
                FROM business_accounts b LEFT JOIN business_members m ON m.business_account_id=b.id AND m.role='OWNER'
                LEFT JOIN users u ON u.id=m.user_id LEFT JOIN billing_subscriptions s ON s.user_id=u.id
                WHERE b.id=?
                """, businessId);
        if (rows.size() != 1) throw new WorkspaceAccessDeniedException();
        var row = rows.getFirst();
        var expiry = (Timestamp) row.get("subscription_expires_at");
        boolean active = "BUSINESS".equals(row.get("subscription_plan")) && expiry != null
                && expiry.toLocalDateTime().isAfter(LocalDateTime.now(clock));
        return new Company(Boolean.TRUE.equals(row.get("sandbox")),
                Boolean.TRUE.equals(row.get("sandbox_entitlement")),
                (String) row.get("billing_customer_id"), active);
    }

    private record Company(boolean sandbox, boolean sandboxEntitlement, String customerId, boolean active) {}
}
