package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.controller.DamageInspectionController;
import com.gorkem.vehicle_inspector.dto.response.DamageInspectionResponse;
import com.gorkem.vehicle_inspector.dto.response.ImageQualityResponse;
import com.gorkem.vehicle_inspector.service.DamageInspectionService;
import com.gorkem.vehicle_inspector.service.NearbyServiceService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.authentication.TestingAuthenticationToken;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

class DamageInspectionControllerTest {
    private DamageInspectionService service;
    private MockMvc mvc;
    private final TestingAuthenticationToken actor = new TestingAuthenticationToken("user@example.com", "unused", "ROLE_USER");

    @BeforeEach
    void setUp() {
        service = mock(DamageInspectionService.class);
        mvc = MockMvcBuilders.standaloneSetup(new DamageInspectionController(
                service, mock(NearbyServiceService.class))).build();
    }

    @Test
    void newClientDefaultsToSinglePhotoAndForwardsRegion() throws Exception {
        when(service.analyzeInspection(1L, actor.getName(), false, "FRONT"))
                .thenReturn(mock(DamageInspectionResponse.class));
        mvc.perform(post("/api/v1/inspections/1/analyze").param("vehicleRegion", "FRONT").principal(actor))
                .andExpect(status().isOk());
        verify(service).analyzeInspection(1L, actor.getName(), false, "FRONT");
    }

    @Test
    void legacyClientCanExplicitlyRequireBothPhotos() throws Exception {
        when(service.analyzeInspection(1L, actor.getName(), true, "REAR"))
                .thenReturn(mock(DamageInspectionResponse.class));
        mvc.perform(post("/api/v1/inspections/1/analyze").param("requireContext", "true")
                        .param("vehicleRegion", "REAR").principal(actor))
                .andExpect(status().isOk());
        verify(service).analyzeInspection(1L, actor.getName(), true, "REAR");
    }

    @Test
    void oldestClientCanOmitRegion() throws Exception {
        when(service.analyzeInspection(1L, actor.getName(), false, null))
                .thenReturn(mock(DamageInspectionResponse.class));
        mvc.perform(post("/api/v1/inspections/1/analyze").principal(actor)).andExpect(status().isOk());
        verify(service).analyzeInspection(1L, actor.getName(), false, null);
    }

    @Test
    void legacyContextUploadAndQualityEndpointsRemainAvailable() throws Exception {
        MockMultipartFile image = new MockMultipartFile("image", "context.jpg", "image/jpeg", new byte[]{1});
        when(service.uploadInspectionContextImage(1L, image, actor.getName())).thenReturn(mock(DamageInspectionResponse.class));
        when(service.validateInspectionContextImage(1L, actor.getName()))
                .thenReturn(new ImageQualityResponse(true, "SUITABLE", "OK"));
        mvc.perform(multipart("/api/v1/inspections/1/context-image").file(image).principal(actor))
                .andExpect(status().isOk());
        mvc.perform(post("/api/v1/inspections/1/context-image-quality").principal(actor))
                .andExpect(status().isOk()).andExpect(jsonPath("$.suitable").value(true));
        verify(service).uploadInspectionContextImage(1L, image, actor.getName());
    }
}
