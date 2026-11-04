// TEST TRANSPORT ONLY. No production app imports this file. No AI/store calls occur.
import http from 'node:http';
import { Buffer } from 'node:buffer';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
if (process.env.NODE_ENV === 'production')
  throw new Error('Visual fixtures cannot run in production.');
const initial = JSON.parse(
  await readFile(new URL('./fixtures.json', import.meta.url), 'utf8'),
);
const clone = (value) => structuredClone(value);
let profile = clone(initial.profile),
  garage = [clone(initial.vehicle)],
  history = [clone(initial.inspection)],
  maintenance = [clone(initial.maintenance)],
  reminders = [clone(initial.reminder)],
  record = null;
const uploads = new Map(),
  events = [];
let scenario = 'default';
const fallback = await readFile(
  new URL('../assets/guide/analysis-dark.png', import.meta.url),
);
const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, 'http://localhost'),
      path = url.pathname.replace(/^\/api\/v1/, ''),
      method = req.method,
      workspace = req.headers['x-workspace'] ?? 'PERSONAL';
    const reply = (body, status = 200) => {
      res.writeHead(status, {
        'Content-Type': 'application/json',
        'X-Workspace': workspace,
      });
      res.end(body === undefined ? '' : JSON.stringify(body));
    };
    const chunks = [];
    let total = 0;
    for await (const chunk of req) {
      total += chunk.length;
      if (total > 12 * 1024 * 1024) {
        reply({ message: 'Test upload limit' }, 413);
        return;
      }
      chunks.push(chunk);
    }
    const bytes = Buffer.concat(chunks);
    const json = () => (bytes.length ? JSON.parse(bytes.toString('utf8')) : {});
    events.push({ method, path, workspace });
    if (path === '/__fixture/events') return reply(events);
    if (path === '/__fixture')
      return reply({ testOnly: true, transport: 'ekspersiz-visual-fixtures' });
    if (path === '/__fixture/scenario' && method === 'POST') {
      const next = json().scenario;
      if (
        ![
          'default',
          'empty',
          'error',
          'business-owner',
          'business-member',
        ].includes(next)
      )
        return reply({ message: 'Unknown test scenario' }, 400);
      scenario = next;
      profile = clone(initial.profile);
      garage = scenario === 'empty' ? [] : [clone(initial.vehicle)];
      history = scenario === 'empty' ? [] : [clone(initial.inspection)];
      if (scenario.startsWith('business-')) {
        profile.subscriptionPlan = 'BUSINESS';
        profile.businessAccount = {
          id: 12,
          companyName:
            'EksperSiz Örnek Otomotiv Bakım ve Filo Yönetimi Şirketi',
          role: scenario === 'business-owner' ? 'OWNER' : 'MEMBER',
          workspaceAvailable: true,
          workspaceAccessStatus: 'ACTIVE',
          sandbox: true,
        };
      }
      return reply({ testOnly: true, scenario });
    }
    if (path === '/app/version') return reply({ minimumAndroidBuild: 1 });
    if (path === '/auth/login')
      return reply({
        ...profile,
        userId: profile.id,
        accessToken: 'visual-only-token',
        tokenType: 'Bearer',
        expiresIn: 3600,
      });
    if (req.headers.authorization !== 'Bearer visual-only-token')
      return reply({ message: 'Visual test token required' }, 401);
    if (scenario === 'error' && /^\/(vehicles|inspections)(\/|$)/.test(path))
      return reply(
        { message: 'Görsel test: bağlantı şu an kullanılamıyor.' },
        503,
      );
    if (path === '/auth/me') return reply(profile);
    if (path === '/workspace')
      return reply({
        type: workspace,
        userId: profile.id,
        businessId:
          workspace === 'BUSINESS' ? profile.businessAccount?.id : null,
      });
    if (path === '/vehicles' && method === 'GET') return reply(garage);
    if (path === '/vehicles' && method === 'POST') {
      const body = json();
      const vehicle = {
        ...body,
        id: Math.max(0, ...garage.map((v) => v.id)) + 1,
        primaryVehicle: garage.length === 0,
      };
      garage.push(vehicle);
      return reply(vehicle, 201);
    }
    const vehicleRoute = path.match(/^\/vehicles\/(\d+)(?:\/(.*))?$/);
    if (vehicleRoute) {
      const id = Number(vehicleRoute[1]),
        suffix = vehicleRoute[2],
        vehicle = garage.find((v) => v.id === id);
      if (!vehicle) return reply({ message: 'Araç bulunamadı.' }, 404);
      if (!suffix) {
        if (method === 'PUT') Object.assign(vehicle, json());
        if (method === 'DELETE') {
          garage = garage.filter((v) => v.id !== id);
          return reply(undefined, 204);
        }
        return reply(vehicle);
      }
      if (suffix === 'primary') {
        garage.forEach((v) => (v.primaryVehicle = v.id === id));
        return reply(vehicle);
      }
      if (suffix === 'overview')
        return reply({
          vehicle,
          trackingStatus: 'UPCOMING',
          disclaimer: 'Takip tarihleri kullanıcı kayıtlarına göre hesaplanır.',
          latestMaintenance: maintenance[0] ?? null,
          upcomingReminders: reminders,
          latestInspectionId: 1,
          latestDamageSeverity: 'MINOR',
          latestInspectionAt: initial.inspection.completedAt,
        });
      if (suffix === 'history')
        return reply([
          {
            type: 'MAINTENANCE',
            title: 'Motor yağı değişimi',
            description: 'Bakım kaydı eklendi.',
            occurredAt: '2026-09-15T09:00:00',
          },
        ]);
      const parts = suffix.split('/'),
        kind = parts[0],
        items = kind === 'maintenance' ? maintenance : reminders,
        entryId = Number(parts[1]);
      if (['maintenance', 'reminders'].includes(kind)) {
        if (method === 'GET') return reply(items);
        if (method === 'DELETE') {
          const next = items.filter((i) => i.id !== entryId);
          if (kind === 'maintenance') maintenance = next;
          else reminders = next;
          return reply(undefined, 204);
        }
        const body = json();
        const existing = items.find((i) => i.id === entryId);
        if (existing) {
          Object.assign(
            existing,
            body,
            parts[2] === 'completion'
              ? {
                  status:
                    url.searchParams.get('completed') === 'true'
                      ? 'COMPLETED'
                      : 'UPCOMING',
                }
              : {},
          );
          return reply(existing);
        }
        const item = {
          ...body,
          id: Math.max(0, ...items.map((i) => i.id)) + 1,
          status: 'UPCOMING',
          createdByName: profile.fullName,
        };
        items.push(item);
        return reply(item, 201);
      }
    }
    if (path === '/inspections' && method === 'GET') return reply(history);
    if (path === '/inspections' && method === 'POST') {
      const vehicle = garage.find(
        (v) => v.id === Number(url.searchParams.get('vehicleId')),
      );
      if (!vehicle) return reply({ message: 'Araç seçin.' }, 400);
      const item = {
        ...clone(initial.inspection),
        id: Math.max(0, ...history.map((i) => i.id)) + 1,
        vehicleId: vehicle.id,
        vehiclePlate: vehicle.plate,
        vehicleBrand: vehicle.brand,
        vehicleModel: vehicle.model,
        imagePath: null,
        contextImagePath: null,
        status: 'PENDING',
        report: null,
        reportStatus: 'PENDING',
        locationCity: url.searchParams.get('city'),
        locationLatitude: Number(url.searchParams.get('latitude')),
        locationLongitude: Number(url.searchParams.get('longitude')),
      };
      history.push(item);
      return reply(item, 201);
    }
    const inspectionRoute = path.match(/^\/inspections\/(\d+)(?:\/(.*))?$/);
    if (inspectionRoute) {
      const id = Number(inspectionRoute[1]),
        suffix = inspectionRoute[2],
        item = history.find((i) => i.id === id);
      if (!item) return reply({ message: 'İnceleme bulunamadı.' }, 404);
      if (!suffix) return reply(item);
      if (suffix === 'image' && method === 'GET') {
        const image = uploads.get(id) ?? fallback;
        res.writeHead(200, {
          'Content-Type': uploads.has(id) ? 'image/jpeg' : 'image/png',
          'Content-Length': image.length,
          'X-Workspace': workspace,
        });
        return res.end(image);
      }
      if (['image', 'context-image'].includes(suffix) && method === 'POST') {
        const contentType = req.headers['content-type'] ?? '',
          boundary = contentType
            .match(/boundary=(?:"([^"]+)"|([^;]+))/)
            ?.slice(1)
            .find(Boolean);
        if (!boundary) return reply({ message: 'Multipart missing' }, 400);
        const start = bytes.indexOf('\r\n\r\n') + 4,
          end = bytes.lastIndexOf(`\r\n--${boundary}`);
        if (start < 4 || end <= start)
          return reply({ message: 'Image missing' }, 400);
        if (suffix === 'image') {
          uploads.set(id, bytes.subarray(start, end));
          item.imagePath = `fixture/${id}/damage.jpg`;
          item.contextImagePath = null;
        } else item.contextImagePath = `fixture/${id}/context.jpg`;
        return reply(item);
      }
      if (suffix.endsWith('image-quality'))
        return reply({
          suitable: true,
          code: 'SUITABLE',
          message: 'Görsel test fotoğrafı işlendi.',
        });
      if (suffix === 'analyze') {
        if (!item.imagePath || !item.contextImagePath)
          return reply({ message: 'İki fotoğraf gerekli.' }, 422);
        item.status = 'COMPLETED';
        item.reportStatus = 'COMPLETED';
        item.report = clone(initial.inspection.report);
        return reply(item);
      }
      if (suffix === 'report') {
        item.report = clone(initial.inspection.report);
        return reply(item);
      }
      if (suffix === 'nearby-services')
        return reply([
          {
            placeId: 'visual-place',
            name: 'Örnek Servis',
            address: 'İstanbul',
            latitude: 41.01,
            longitude: 28.98,
            rating: 4.5,
            userRatingCount: 42,
            distanceKm: 1.2,
            googleMapsUri:
              'https://www.google.com/maps/search/?api=1&query=41.01,28.98',
          },
        ]);
      if (suffix === 'damage-record/finalize') {
        if (!record || record.inspectionId !== id)
          return reply({ message: 'Taslak yok' }, 404);
        record.status = 'FINALIZED';
        record.finalizedAt = new Date().toISOString();
        record.updatedAt = record.finalizedAt;
        record.snapshotJson = JSON.stringify({
          documentVersion: 1,
          recordNumber: record.recordNumber,
          finalizedAt: record.finalizedAt,
          incidentDateTime: record.incidentDateTime,
          incidentCity: record.incidentCity,
          incidentDistrict: record.incidentDistrict,
          incidentAddress: record.incidentAddress,
          incidentDescription: record.incidentDescription,
          declarantFullName: record.declarantFullName,
          vehicle: {
            plate: item.vehiclePlate,
            brand: item.vehicleBrand,
            model: item.vehicleModel,
            modelYear: item.vehicleModelYear,
            mileage: item.vehicleMileage,
          },
          analysis: { ...item, inspectionId: id },
          report: item.report,
        });
        record.contentHash = createHash('sha256')
          .update(record.snapshotJson, 'utf8')
          .digest('hex');
        return reply(record);
      }
      if (suffix === 'damage-record' && method === 'GET')
        return record && record.inspectionId === id
          ? reply(record)
          : reply({ message: 'Taslak yok' }, 404);
      if (suffix === 'damage-record') {
        record = {
          ...json(),
          id: 1,
          inspectionId: id,
          recordNumber: 'EXP-TEST-1',
          status: 'DRAFT',
          documentVersion: 1,
          updatedAt: new Date().toISOString(),
        };
        return reply(record, method === 'POST' ? 201 : 200);
      }
    }
    if (path === '/analysis-quota')
      return reply({
        plan: 'FREE',
        used: 0,
        limit: 5,
        remaining: 5,
        freeRemaining: 0,
        purchasedCredits: 5,
      });
    if (path === '/billing' || path === '/billing/sync')
      return reply(initial.billing);
    if (path === '/credits') {
      const credits = clone(initial.credits);
      if (scenario.startsWith('business-'))
        credits.company = {
          ...clone(credits.personal),
          totalSlots: 10,
          owner: scenario === 'business-owner',
        };
      return reply(credits);
    }
    if (path === '/business-members')
      return reply([
        {
          id: 1,
          userId: 7,
          fullName: 'Deniz Yılmaz',
          email: 'deniz@example.com',
          role: 'OWNER',
        },
        {
          id: 2,
          userId: 8,
          fullName: 'Örnek Uzun İsimli Ekip Üyesi',
          email: 'uzun.isimli.ornek.ekip.uyesi@example.com',
          role: 'MEMBER',
        },
      ]);
    if (path === '/ai-assistant/entitlement') return reply(initial.assistant);
    if (path === '/ai-assistant/chat')
      return reply({
        intent: 'AUTOMOTIVE',
        answer:
          '**Bakım planı**\n\n- Yağ seviyesini düzenli kontrol edin.\n- Üreticinin bakım aralığını izleyin.\n\nKesin kontrol için servis desteği alın.',
        quotaConsumed: true,
        remainingToday: 9,
        toolsUsed: [],
        sources: [],
      });
    if (path === '/notifications/unread-count')
      return reply({ unreadCount: 1 });
    if (path === '/notifications')
      return reply([
        {
          id: 1,
          vehicleId: 1,
          notificationType: 'REMINDER',
          severity: 'WARNING',
          title: 'Sigorta tarihiniz yaklaşıyor',
          body: 'Poliçe tarihini kontrol edin.',
          read: false,
          createdAt: '2026-10-29T09:00:00',
        },
      ]);
    reply({ message: `Unsupported TEST fixture: ${method} ${path}` }, 404);
  } catch (error) {
    res.writeHead(500, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ message: String(error) }));
  }
});
// CI uses port 0 to avoid colliding with an active emulator fixture session.
const port = Number(process.env.UI_FIXTURE_PORT ?? 18080);
if (!Number.isInteger(port) || port < 0 || port > 65535)
  throw new Error('Invalid UI_FIXTURE_PORT.');
server.listen(port, '127.0.0.1', () =>
  console.log(
    `TEST-ONLY visual fixture transport: 127.0.0.1:${server.address().port}`,
  ),
);
