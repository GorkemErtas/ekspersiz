package com.gorkem.vehicle_inspector.service.workspace;

import com.gorkem.vehicle_inspector.entity.BusinessMember;
import com.gorkem.vehicle_inspector.exception.WorkspaceAccessDeniedException;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.stereotype.Component;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

import java.util.Collections;
import java.util.Optional;

@Component
public class WorkspaceResolver {
    public static final String HEADER = "X-Workspace";
    private static final String ATTRIBUTE = WorkspaceContext.class.getName();

    private static HttpServletRequest request() {
        return RequestContextHolder.getRequestAttributes() instanceof ServletRequestAttributes attributes
                ? attributes.getRequest() : null;
    }

    public static WorkspaceType requestedType() {
        var request = request();
        if (request == null || request.getHeader(HEADER) == null) return null;
        var values = Collections.list(request.getHeaders(HEADER));
        if (values.size() != 1) throw new IllegalArgumentException("Tek bir X-Workspace başlığı gönderilmelidir.");
        try { return WorkspaceType.valueOf(values.getFirst()); }
        catch (IllegalArgumentException invalid) {
            throw new IllegalArgumentException("X-Workspace yalnız PERSONAL veya BUSINESS olabilir.");
        }
    }

    public WorkspaceContext resolve(long userId, Optional<BusinessMember> membership) {
        var request = request();
        var pinned = request == null ? null : (WorkspaceContext) request.getAttribute(ATTRIBUTE);
        if (pinned != null) {
            if (pinned.userId() != userId || (pinned.business() &&
                    membership.map(m -> !m.getBusinessAccount().getId().equals(pinned.businessId())).orElse(true))) {
                throw new WorkspaceAccessDeniedException();
            }
            return pinned;
        }
        var type = requestedType();
        if (type == null) type = membership.isPresent() ? WorkspaceType.BUSINESS : WorkspaceType.PERSONAL;
        Long businessId = null;
        if (type == WorkspaceType.BUSINESS) {
            businessId = membership.orElseThrow(WorkspaceAccessDeniedException::new).getBusinessAccount().getId();
        }
        var context = new WorkspaceContext(type, userId, businessId);
        if (request != null) request.setAttribute(ATTRIBUTE, context);
        return context;
    }

    /** Credit completion uses the original reservation account; release never calls this. */
    public static void requireAccount(long userId, String accountId) {
        var type = requestedType();
        if (type != null && (type == WorkspaceType.BUSINESS) != accountId.startsWith("business:")) {
            throw new WorkspaceAccessDeniedException();
        }
        var request = request();
        var pinned = request == null ? null : (WorkspaceContext) request.getAttribute(ATTRIBUTE);
        if (pinned != null && (pinned.userId() != userId || !pinned.accountId().equals(accountId))) {
            throw new WorkspaceAccessDeniedException();
        }
    }
}
