package com.gorkem.vehicle_inspector.service.workspace;

/** Immutable identity pinned to one request, never shared across requests. */
public record WorkspaceContext(WorkspaceType type, long userId, Long businessId) {
    public boolean business() { return type == WorkspaceType.BUSINESS; }
    public String accountId() { return business() ? "business:" + businessId : "user:" + userId; }
}
