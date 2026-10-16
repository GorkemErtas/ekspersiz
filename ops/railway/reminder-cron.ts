/**
 * Railway Function (Bun script), configured as a cron service.
 * Cron: 0 6 * * * UTC = 09:00 Europe/Istanbul.
 * Do not start an HTTP server; Railway needs this process to exit.
 *
 * Required variables: REMINDER_BACKEND_URL and REMINDER_JOB_TOKEN.
 */
const baseUrl = Bun.env.REMINDER_BACKEND_URL?.trim();
const jobToken = Bun.env.REMINDER_JOB_TOKEN?.trim();

if (!baseUrl || !baseUrl.startsWith("https://") || !jobToken) {
  throw new Error("Missing or invalid reminder cron configuration");
}

const endpoint = new URL("/api/v1/internal/reminders/execute", baseUrl);
const maxAttempts = 8;
const delayMs = 15_000;
let completed = false;

for (let attempt = 1; attempt <= maxAttempts; attempt++) {
  try {
    // Initial requests may return 502 while Railway wakes a sleeping JVM/DB.
    const response = await fetch(endpoint, {
      method: "POST",
      headers: {
        "X-Reminder-Job-Token": jobToken,
        Accept: "application/json",
      },
      signal: AbortSignal.timeout(25_000),
    });

    if (response.ok) {
      const result = (await response.json()) as { status?: string };
      if (result.status !== "processed") {
        throw new Error("Backend returned an unexpected success response");
      }
      console.log(`Daily reminder evaluation succeeded (attempt ${attempt})`);
      completed = true;
      break;
    }

    // Misconfiguration cannot be fixed by retrying.
    if ([400, 401, 403, 404].includes(response.status)) {
      console.error(`Reminder job rejected with HTTP ${response.status}`);
      break;
    }

    console.warn(`Reminder job attempt ${attempt} returned HTTP ${response.status}`);
  } catch (error) {
    // Do not log tokens, URLs with credentials, or response bodies.
    const type = error instanceof Error ? error.name : "UnknownError";
    console.warn(`Reminder job attempt ${attempt} failed: ${type}`);
  }

  if (attempt < maxAttempts) {
    await Bun.sleep(delayMs);
  }
}

if (!completed) {
  console.error("Daily reminder evaluation failed after available retries");
  process.exitCode = 1;
}
