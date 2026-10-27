package com.gorkem.vehicle_inspector.service.billing;

import com.gorkem.vehicle_inspector.entity.User;
import com.gorkem.vehicle_inspector.exception.WorkspaceAccessDeniedException;
import com.gorkem.vehicle_inspector.service.workspace.BusinessWorkspaceAccess;
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
        return workspaceAccess(actor, businessId) == BusinessWorkspaceAccess.ACTIVE;
    }

    public BusinessWorkspaceAccess workspaceAccess(User actor, long businessId) {
        var company = company(businessId);
        if (company == null || company.customerId() == null) return BusinessWorkspaceAccess.OWNER_UNAVAILABLE;
        if (company.sandbox() != company.sandboxEntitlement()) return BusinessWorkspaceAccess.ENVIRONMENT_MISMATCH;
        if (company.sandbox() && (!testers.allows(actor) || !testers.allowsCustomerId(company.customerId())))
            return BusinessWorkspaceAccess.SANDBOX_NOT_AUTHORIZED;
        if (!company.active()) return company.expired()
                ? BusinessWorkspaceAccess.SUBSCRIPTION_EXPIRED : BusinessWorkspaceAccess.SUBSCRIPTION_INACTIVE;
        return BusinessWorkspaceAccess.ACTIVE;
    }

    public void requireActiveCompany(User actor, long businessId) {
        requireCompanyAccess(actor, businessId);
    }

    public void requireInvitation(User owner, User invited, long businessId) {
        requireActiveCompany(owner, businessId);
        if (sandboxCompany(businessId) && !testers.allows(invited)) {
            throw new IllegalStateException("Test şirketine yalnızca sunucuda yetkilendirilmiş test hesapları katılabilir.");
        }
    }

    public boolean companyEntitlementActive(long businessId) {
        var company = company(businessId);
        return company != null && company.active() && (company.sandbox()
                ? company.sandboxEntitlement() && testers.allowsCustomerId(company.customerId())
                : !company.sandboxEntitlement());
    }

    private Company company(long businessId) {
        var rows = jdbc.queryForList("""
                SELECT b.sandbox, u.billing_customer_id, u.subscription_plan, u.subscription_expires_at,
                       s.status, s.current_period_ends_at, COALESCE(s.sandbox,FALSE) AS sandbox_entitlement
                FROM business_accounts b LEFT JOIN business_members m ON m.business_account_id=b.id AND m.role='OWNER'
                LEFT JOIN users u ON u.id=m.user_id LEFT JOIN billing_subscriptions s ON s.user_id=u.id
                WHERE b.id=?
                """, businessId);
        if (rows.size() != 1) return null;
        var row = rows.getFirst();
        var expiry = (Timestamp) row.get("subscription_expires_at");
        boolean active = "BUSINESS".equals(row.get("subscription_plan")) && expiry != null
                && expiry.toLocalDateTime().isAfter(LocalDateTime.now(clock))
                && (row.get("status") == null || java.util.Set.of("ACTIVE", "CANCELLED", "BILLING_ISSUE").contains(row.get("status")));
        var periodEnd = expiry != null ? expiry : (Timestamp) row.get("current_period_ends_at");
        boolean expired = periodEnd != null && !periodEnd.toLocalDateTime().isAfter(LocalDateTime.now(clock));
        return new Company(Boolean.TRUE.equals(row.get("sandbox")),
                Boolean.TRUE.equals(row.get("sandbox_entitlement")),
                (String) row.get("billing_customer_id"), active, expired);
    }

    private record Company(boolean sandbox, boolean sandboxEntitlement, String customerId, boolean active, boolean expired) {}
}
