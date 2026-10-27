package com.gorkem.vehicle_inspector.dto.response;

import com.gorkem.vehicle_inspector.entity.BusinessRole;
import com.gorkem.vehicle_inspector.service.workspace.BusinessWorkspaceAccess;

public record BusinessAccountResponse(
        Long id,
        String companyName,
        BusinessRole role,
        boolean sandbox,
        boolean workspaceAvailable,
        BusinessWorkspaceAccess workspaceAccessStatus
) {
    public BusinessAccountResponse(Long id, String companyName, BusinessRole role) {
        this(id, companyName, role, false);
    }

    public BusinessAccountResponse(Long id, String companyName, BusinessRole role, boolean sandbox) {
        this(id, companyName, role, sandbox, BusinessWorkspaceAccess.UNKNOWN);
    }

    public BusinessAccountResponse(Long id, String companyName, BusinessRole role, boolean sandbox, BusinessWorkspaceAccess access) {
        this(id, companyName, role, sandbox, access == BusinessWorkspaceAccess.ACTIVE, access);
    }
}
