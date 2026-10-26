package com.gorkem.vehicle_inspector.config;

import com.gorkem.vehicle_inspector.repository.BusinessMemberRepository;
import com.gorkem.vehicle_inspector.security.AuthenticatedUser;
import com.gorkem.vehicle_inspector.service.BusinessContextService;
import com.gorkem.vehicle_inspector.service.workspace.WorkspaceResolver;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.authentication.AnonymousAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WorkspaceWebConfig implements WebMvcConfigurer {
    private final BusinessContextService context;
    private final BusinessMemberRepository members;
    private final WorkspaceResolver workspaces;

    public WorkspaceWebConfig(BusinessContextService context, BusinessMemberRepository members, WorkspaceResolver workspaces) {
        this.context = context; this.members = members; this.workspaces = workspaces;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(new HandlerInterceptor() {
            @Override
            public boolean preHandle(jakarta.servlet.http.HttpServletRequest request,
                                     jakarta.servlet.http.HttpServletResponse response, Object handler) {
                var auth = SecurityContextHolder.getContext().getAuthentication();
                if (auth != null && auth.isAuthenticated() && !(auth instanceof AnonymousAuthenticationToken)) {
                    long userId = auth.getPrincipal() instanceof AuthenticatedUser identity
                            ? identity.getUserId() : context.requireUser(auth.getName()).getId();
                    var workspace = workspaces.resolve(userId,
                            WorkspaceResolver.requestedType() == com.gorkem.vehicle_inspector.service.workspace.WorkspaceType.PERSONAL
                                    ? java.util.Optional.empty() : members.findByUserId(userId));
                    response.setHeader(WorkspaceResolver.HEADER, workspace.type().name());
                }
                return true;
            }
        }).addPathPatterns("/api/v1/**").excludePathPatterns(
                "/api/v1/auth/**", "/api/v1/health", "/api/v1/app/**",
                "/api/v1/internal/**", "/api/v1/billing/revenuecat/webhook");
    }
}
