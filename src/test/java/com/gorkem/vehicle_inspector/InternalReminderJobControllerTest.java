package com.gorkem.vehicle_inspector;

import com.gorkem.vehicle_inspector.controller.InternalReminderJobController;
import com.gorkem.vehicle_inspector.service.ReminderNotificationScheduler;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.web.server.ResponseStatusException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.*;

class InternalReminderJobControllerTest {
    private final ReminderNotificationScheduler scheduler =
            mock(ReminderNotificationScheduler.class);

    @Test
    void missingConfiguredSecretFailsClosed() {
        InternalReminderJobController controller =
                new InternalReminderJobController(scheduler, "");

        ResponseStatusException error = assertThrows(
                ResponseStatusException.class,
                () -> controller.execute("any-token"));

        assertEquals(HttpStatus.SERVICE_UNAVAILABLE, error.getStatusCode());
        verifyNoInteractions(scheduler);
    }

    @Test
    void missingOrWrongSecretNeverRunsJob() {
        InternalReminderJobController controller =
                new InternalReminderJobController(scheduler, "long-secret-value");

        for (String token : new String[] {null, "", "incorrect"}) {
            ResponseStatusException error = assertThrows(
                    ResponseStatusException.class,
                    () -> controller.execute(token));
            assertEquals(HttpStatus.UNAUTHORIZED, error.getStatusCode());
        }
        verifyNoInteractions(scheduler);
    }

    @Test
    void correctSecretRunsExistingEvaluationOnce() {
        InternalReminderJobController controller =
                new InternalReminderJobController(scheduler, "long-secret-value");

        assertEquals("processed", controller.execute("long-secret-value")
                .getBody().get("status"));
        verify(scheduler, times(1)).evaluateDueReminders();
    }

    @Test
    void processingFailurePropagatesSoWorkerCanRetry() {
        InternalReminderJobController controller =
                new InternalReminderJobController(scheduler, "long-secret-value");
        doThrow(new IllegalStateException("database unavailable"))
                .when(scheduler).evaluateDueReminders();

        assertThrows(IllegalStateException.class,
                () -> controller.execute("long-secret-value"));
    }
}
