package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.client.AiAssistantClient;
import com.gorkem.vehicle_inspector.dto.request.AiAssistantChatRequest;
import com.gorkem.vehicle_inspector.dto.response.*;
import com.gorkem.vehicle_inspector.service.*;
import org.junit.jupiter.api.Test;

import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class AiAssistantChatServiceTest {

    @Test
    void outOfScopeDoesNotConsumeQuota() {
        var client = mock(AiAssistantClient.class);
        var entitlement = mock(AiAssistantEntitlementService.class);
        var tools = mock(AiAssistantToolContextService.class);
        var generation = mock(AiAssistantGenerationService.class);
        var service = new AiAssistantChatService(client, entitlement, tools, generation);

        when(client.plan("Bana şiir yaz")).thenReturn(plan(false, false, null, List.of()));
        when(entitlement.status("user@example.com")).thenReturn(status(3));

        var response = service.chat(
                new AiAssistantChatRequest("Bana şiir yaz", null, List.of()),
                "user@example.com");

        assertFalse(response.quotaConsumed());
        assertEquals(3, response.remainingToday());
        verify(entitlement).recordOutOfScope("user@example.com");
        verify(entitlement, never()).reserveQuestion(anyString());
        verifyNoInteractions(generation);
    }

    @Test
    void weakRagEvidenceIsRefusedWithoutQuota() {
        var client = mock(AiAssistantClient.class);
        var entitlement = mock(AiAssistantEntitlementService.class);
        var tools = mock(AiAssistantToolContextService.class);
        var generation = mock(AiAssistantGenerationService.class);
        var service = new AiAssistantChatService(client, entitlement, tools, generation);

        when(client.plan("Lastik basıncı?")).thenReturn(plan(true, true, null, List.of()));
        when(entitlement.status("user@example.com")).thenReturn(status(3));

        var response = service.chat(
                new AiAssistantChatRequest("Lastik basıncı?", null, List.of()),
                "user@example.com");

        assertFalse(response.quotaConsumed());
        verify(entitlement, never()).reserveQuestion(anyString());
        verifyNoInteractions(generation);
    }


    @Test
    void clarificationDoesNotConsumeQuota() {
        var client = mock(AiAssistantClient.class);
        var entitlement = mock(AiAssistantEntitlementService.class);
        var tools = mock(AiAssistantToolContextService.class);
        var generation = mock(AiAssistantGenerationService.class);
        var service = new AiAssistantChatService(client, entitlement, tools, generation);

        var plan = new AiAssistantPlanResponse(
                "VEHICLE_SPEC", true, true, null, "missing vehicle year",
                0.95, 0.90, 0.0, true, true,
                "Bunu doğru yanıtlayabilmem için model yılı bilgisini paylaşır mısınız?",
                List.of());
        when(client.plan("Corolla kaç airbag?")).thenReturn(plan);
        when(entitlement.status("user@example.com")).thenReturn(status(3));

        var response = service.chat(
                new AiAssistantChatRequest("Corolla kaç airbag?", null, List.of()),
                "user@example.com");

        assertFalse(response.quotaConsumed());
        assertTrue(response.answer().contains("model yılı"));
        verify(entitlement, never()).reserveQuestion(anyString());
        verify(entitlement, never()).recordOutOfScope(anyString());
        verifyNoInteractions(generation);
    }

    @Test
    void successfulAnswerConsumesReservationAndCarriesSourcesAndHistory() {
        var client = mock(AiAssistantClient.class);
        var entitlement = mock(AiAssistantEntitlementService.class);
        var tools = mock(AiAssistantToolContextService.class);
        var generation = mock(AiAssistantGenerationService.class);
        var service = new AiAssistantChatService(client, entitlement, tools, generation);
        var context = List.of(new AiAssistantPlanResponse.AiAssistantRetrievedContext(
                "Lastik Bakımı", "MAINTENANCE", "İçerik", 0.91,
                "EksperSiz Bilgi Bankası", null));
        var history = List.of(new AiAssistantChatRequest.HistoryMessage(
                "user", "Kışın basınç düşer mi?"));

        when(client.plan("Ne sıklıkla kontrol edeyim?"))
                .thenReturn(plan(true, true, null, context));
        when(entitlement.reserveQuestion("user@example.com")).thenReturn(UUID.fromString(
                "11111111-1111-1111-1111-111111111111"));
        when(generation.generate(eq("Ne sıklıkla kontrol edeyim?"), any(), isNull(), eq(history)))
                .thenReturn("Ayda en az bir kez kontrol edin.");
        when(entitlement.status("user@example.com")).thenReturn(status(2));

        var response = service.chat(
                new AiAssistantChatRequest("Ne sıklıkla kontrol edeyim?", null, history),
                "user@example.com");

        assertTrue(response.quotaConsumed());
        assertEquals(2, response.remainingToday());
        assertEquals(1, response.sources().size());
        assertEquals("EksperSiz Bilgi Bankası", response.sources().getFirst().name());
        verify(entitlement).completeReservedQuestion(
                eq("user@example.com"), any(UUID.class));
    }

    @Test
    void generationFailureReleasesReservation() {
        var client = mock(AiAssistantClient.class);
        var entitlement = mock(AiAssistantEntitlementService.class);
        var tools = mock(AiAssistantToolContextService.class);
        var generation = mock(AiAssistantGenerationService.class);
        var service = new AiAssistantChatService(client, entitlement, tools, generation);
        var token = UUID.fromString("22222222-2222-2222-2222-222222222222");

        when(client.plan("Motor yağı ne zaman değişir?"))
                .thenReturn(plan(true, false, null, List.of()));
        when(entitlement.reserveQuestion("user@example.com")).thenReturn(token);
        when(generation.generate(anyString(), any(), isNull(), any()))
                .thenThrow(new RuntimeException("provider unavailable"));

        assertThrows(RuntimeException.class, () -> service.chat(
                new AiAssistantChatRequest("Motor yağı ne zaman değişir?", null, List.of()),
                "user@example.com"));

        verify(entitlement).releaseReservedQuestion("user@example.com", token);
        verify(entitlement, never()).completeReservedQuestion(anyString(), any());
    }

    private AiAssistantPlanResponse plan(boolean inScope, boolean useRag, String tool,
            List<AiAssistantPlanResponse.AiAssistantRetrievedContext> context) {
        return new AiAssistantPlanResponse(
                "GENERAL", inScope, useRag, tool, "test", 0.9, 0.9,
                context.isEmpty() && useRag ? 0.2 : 0.9,
                !useRag || !context.isEmpty(), false, null, context);
    }

    private AiAssistantEntitlementResponse status(int remaining) {
        return new AiAssistantEntitlementResponse(
                com.gorkem.vehicle_inspector.entity.AiAssistantAccessStatus.TRIAL,
                remaining > 0, 3, 3 - remaining, remaining, 0,
                null, null, null);
    }
}
