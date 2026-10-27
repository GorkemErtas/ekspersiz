package com.gorkem.vehicle_inspector.service.workspace;

/** Membership is retained independently of this current, server-computed authorization. */
public enum BusinessWorkspaceAccess {
    ACTIVE,
    SUBSCRIPTION_EXPIRED,
    SUBSCRIPTION_INACTIVE,
    SANDBOX_NOT_AUTHORIZED,
    ENVIRONMENT_MISMATCH,
    OWNER_UNAVAILABLE,
    UNKNOWN
}
