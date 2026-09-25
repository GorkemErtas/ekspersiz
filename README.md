# 🚗 EksperSiz — AI-Powered Vehicle Inspector

EksperSiz is a production-deployed Android application for AI-assisted vehicle damage analysis and vehicle management. It combines a **Flutter** mobile client, **Spring Boot** backend, **FastAPI/YOLO** computer-vision service, **Google Gemini**, **PostgreSQL**, **Google Maps / Places**, **RevenueCat**, **Firebase Cloud Messaging**, and **Brevo** transactional email.

The application analyzes vehicle photos, detects visible damage and affected parts, recommends repair actions, generates an AI-assisted inspection report with an estimated repair price range, and helps users manage vehicles, maintenance, reminders, inspections, subscriptions, and nearby automotive services.

> AI-generated damage findings and repair-price estimates are informational. They are not a replacement for a physical inspection or a binding repair quote.

---

## ✨ Highlights

- 🔐 Email/password authentication with JWT
- 🔑 Google Sign-In with server-side Google ID-token verification
- ✉️ Email verification and password reset through the Brevo API
- 🗑 Authenticated account deletion with related personal-data cleanup
- 🔒 Secure mobile token storage and persistent sessions
- 🚙 Personal and shared business vehicle management
- 🔧 Maintenance records, mileage tracking, and reminders
- 🔔 Persistent notifications and Firebase Cloud Messaging
- 📷 Camera/gallery vehicle image upload with pre-analysis validation
- 🤖 YOLO-based vehicle damage and affected-part detection
- ⚠️ Damage severity and repair-action recommendations
- 🧠 Gemini-powered inspection reports
- 💰 Location-aware AI repair-cost estimation
- 📄 Branded PDF inspection reports and native sharing
- 🗺 Google Maps and Google Places nearby-service discovery
- 💳 FREE, PLUS, PRO, and BUSINESS subscription plans
- 🏢 Business accounts, invitations, members, and shared vehicles
- 🧾 RevenueCat server-side subscription verification and webhooks
- 🌐 Turkish and English interface
- 🌗 Persistent light/dark theme support

---

## 🏗 Production Architecture

```text
Flutter Android App
        │
        │ HTTPS
        ▼
Spring Boot REST API ───────────────► Brevo API
        │                              Transactional Email
        │
        ├────────────► PostgreSQL
        │
        ├────────────► Persistent Upload Storage
        │
        ├────────────► FastAPI / YOLO
        │                 Private Service
        │
        ├────────────► Google Gemini API
        │
        ├────────────► Google Places API
        │
        ├────────────► RevenueCat
        │
        └────────────► Firebase Cloud Messaging
```

The backend and AI service are containerized and deployed on **Railway**. The Spring Boot API is the public application backend; PostgreSQL and the FastAPI/YOLO service are accessed through the deployment environment. Uploaded inspection images use persistent storage.

The backend container runs the Java application as a non-root application user. Runtime secrets and service credentials are supplied through environment variables and are not committed to the repository.

---

## 🛠 Tech Stack

### Mobile
- Flutter / Dart
- Google Sign-In
- Google Maps Flutter
- Geolocator / Geocoding
- Flutter Secure Storage
- RevenueCat Flutter SDK
- Firebase Cloud Messaging
- PDF generation and native sharing

### Backend
- Java 21
- Spring Boot
- Spring Security
- Spring Data JPA
- Flyway
- JWT
- PostgreSQL
- Brevo REST API
- Firebase Admin SDK
- RevenueCat REST API / webhooks
- Maven

### AI / Computer Vision
- Python
- FastAPI
- Ultralytics YOLO
- PyTorch
- Google Gemini API

### Infrastructure
- Docker
- Railway
- PostgreSQL
- Persistent upload volume
- Google Play Console

---

## 🔄 Inspection Workflow

```text
Create / Select Vehicle
        │
        ▼
Capture or Select Vehicle Photo
        │
        ▼
Image Suitability Validation
        │
        ├── excessive blur
        ├── unusable darkness
        └── invalid vehicle framing
        │
        ▼
FastAPI / YOLO Analysis
        │
        ├── damage detection
        ├── affected-part detection
        ├── severity classification
        └── repair recommendation
        │
        ▼
Persist Structured ML Result
        │
        ▼
Gemini Report Generation
        │
        ├── damage summary
        ├── repair explanation
        └── estimated price range
        │
        ▼
Inspection Result
        │
        ├── PDF export / sharing
        └── nearby service discovery
```

ML analysis and Gemini report generation have separate statuses. If report generation temporarily fails, the completed ML result remains available and the report can be regenerated without running YOLO again.

A valid analysis with no visible damage is stored as a completed inspection using `NO_VISIBLE_DAMAGE`, `NONE`, and `NO_ACTION`. Unsuitable photos are rejected before analysis quota is reserved.

---

## 🧪 AI / ML Pipeline

The current computer-vision path is:

```text
Vehicle Detection
  → Damage Object Detection
  → Vehicle Part Detection
  → Bounding-Box Matching
  → Canonical Structured Result
```

The reviewed Detection V2 checkpoint is stored at:

```text
ai-service/models/candidates/damage_detection_v2_cardd_5class.pt
```

Its damage classes are:

- `SCRATCH`
- `DENT`
- `CRACK`
- `BROKEN_PART`
- `BROKEN_GLASS`

The application domain also supports `PAINT_DAMAGE`, `DEFORMATION`, and the deterministic `NO_VISIBLE_DAMAGE` result. Model class names are mapped to canonical application values rather than relying on numeric class ordering.

Dataset preparation, model evaluation, training commands, and error analysis are documented in [`ai-service/README.md`](ai-service/README.md).

---

## 🧠 AI Report & Repair-Cost Estimation

After computer-vision inference, the backend can provide Gemini with structured context such as vehicle information, mileage, inspection location, detected damage, affected parts, severity, confidence, recommended repair actions, and replacement requirements.

Gemini generates a user-readable report and estimated repair-price range. The application does **not** treat this estimate as live repair-shop pricing or a final quotation.

---

## 🚙 Vehicle Management

Users can manage:

- Vehicles and a main vehicle
- Vehicle archiving while preserving history
- Maintenance records and optional costs
- Mileage records
- Date- and mileage-based reminders
- Inspection history
- Unified vehicle history
- Vehicle condition overview

Tracking fields are optional during vehicle creation. The backend owns deterministic reminder calculations, while the mobile client focuses on data entry and presentation.

---

## 🏢 Business Accounts

EksperSiz uses a single `User` identity model. A `BusinessAccount` contains shared company data and `BusinessMember` connects a user to a company with an `OWNER` or `MEMBER` role.

Business functionality includes:

- Company creation for BUSINESS subscribers
- Registered-user invitations
- Owner/member permissions
- Shared company vehicles
- Company-scoped inspection history
- Shared monthly analysis limits
- Employee listing and membership removal

A vehicle belongs either to a personal user or a business account.

Account deletion is intentionally blocked while a user still has a business membership. The membership/ownership relationship must first be resolved so shared company data is not accidentally deleted.

---

## 💳 Subscriptions & Billing

Supported plans:

| Plan | Active vehicles | Monthly AI analyses |
| --- | ---: | ---: |
| FREE | 1 | 1 |
| PLUS | 3 | 5 |
| PRO | 10 | 20 |

The BUSINESS plan uses company-level limits and shared resources.

Android subscriptions are integrated through **Google Play + RevenueCat**. The mobile client does not authoritatively choose a plan. After purchase or restore, the backend verifies RevenueCat state and synchronizes the user's subscription.

Current Android product IDs:

| Plan | Product ID | RevenueCat package |
| --- | --- | --- |
| PLUS | `eksper_plus_monthly` | `plus_monthly` |
| PRO | `eksper_pro_monthly` | `pro_monthly` |
| BUSINESS | `eksper_business_monthly` | `business_monthly` |

RevenueCat webhook requests are protected by a private authorization value. Optional webhook-signing support is configuration-driven; secrets remain server-side.

---

## 🔔 Notifications

Spring Boot stores persistent notification records and can deliver push notifications through Firebase Cloud Messaging.

The reminder scheduler is configurable through environment variables and defaults to the `Europe/Istanbul` time zone. Notification event keys make scheduled reminder creation idempotent.

For shared company vehicles, current company members receive their own notification records and independent read state.

---

## 🔐 Authentication & Account Lifecycle

EksperSiz supports two authentication paths:

### Email / Password
Registration first creates a short-lived pending registration. A verification code is sent through **Brevo**. The permanent user is created only after successful email verification.

Password reset codes are also delivered through the Brevo HTTPS API.

### Google Sign-In
Flutter uses Google Sign-In and sends the returned Google ID token to the backend. Spring Boot verifies the token's signature/audience and requires a verified Google email before establishing an EksperSiz session.

The application never receives or stores the user's Google password.

### Account Deletion
Authenticated users can request account deletion from the application. Personal vehicles and dependent personal records are removed transactionally, and stored inspection images are cleaned up after the database transaction commits.

Business members must first resolve their company membership to protect shared business records.

---

## 🔒 Security

Security measures currently include:

- JWT-based stateless authentication
- BCrypt password hashing
- Server-side Google ID-token verification
- Verified-email requirement
- Role and business-membership authorization
- Secure mobile token storage
- Authenticated inspection/resource access
- Upload size and MIME-type validation
- Image file-signature validation
- UUID-based stored filenames
- Path-traversal protection
- Non-root backend container runtime
- HTTPS production API
- Environment-based secrets
- RevenueCat server-side subscription verification
- Authenticated account deletion

No API keys, private credentials, signing passwords, Firebase service-account JSON, database passwords, or billing secrets should be committed to the repository.

---

## ⚙️ Configuration

Production configuration is supplied through environment variables. Important categories include:

```text
DATABASE_URL / DB_USERNAME / DB_PASSWORD
JWT_SECRET
UPLOAD_DIR
AI_SERVICE_BASE_URL
GEMINI_API_KEY
GOOGLE_PLACES_API_KEY
GOOGLE_AUTH_CLIENT_ID
FCM_ENABLED / FIREBASE_CREDENTIALS_JSON
REVENUECAT_SECRET_API_KEY
REVENUECAT_WEBHOOK_AUTHORIZATION
BREVO_API_KEY
BREVO_SENDER_EMAIL
BREVO_SENDER_NAME
```

Flutter production values such as the API base URL, Google OAuth client ID, and RevenueCat public Android SDK key are supplied at build time. Private backend secrets must never be placed in Flutter `dart-define` files.

---

## 🐳 Backend Container

The root `Dockerfile` uses a multi-stage Java 21 build. The runtime image:

- contains only the packaged application and required runtime
- prepares the persistent upload directory
- runs the Spring Boot process as the `ekspersiz` system user

The AI service has its own deployment configuration under `ai-service/`.

---

## 🧪 Testing

The project contains unit and persistence/integration coverage for core backend behavior including authentication, billing, business rules, reminders, inspections, and account deletion.

Useful local checks:

```bash
./mvnw test
```

```bash
cd mobile
flutter analyze
flutter test
```

A production Android App Bundle can be built with the project's ignored production dart-define file:

```bash
flutter build appbundle --release --dart-define-from-file=dart_defines.prod.json
```

Do not commit that environment-specific file if it contains deployment configuration that should remain local.

---

## 📱 Android Release Status

Current mobile version:

```text
1.0.0+9
```

EksperSiz has been deployed to the **Google Play closed-testing track**. The production backend, PostgreSQL database, persistent image storage, private AI service, Google authentication, subscription flow, maps/places integration, push-notification infrastructure, and transactional-email flow have been configured for the deployed environment.

---

## 🚀 Current Focus

The core end-to-end application is implemented and deployed for closed testing. Current work focuses on:

- Real-device closed testing and feedback
- ML model quality and dataset improvements
- Reliability and security hardening
- Automated test coverage
- Production-release preparation after closed testing

---

## 👨‍💻 Author

**Görkem Ertaş**  
Software Engineer

---

## ⚠️ Disclaimer

EksperSiz performs AI-assisted analysis of visible vehicle images. Results can be incomplete or inaccurate and do not constitute a mechanical inspection, expert appraisal, insurance assessment, or guaranteed repair quote. For safety-critical or financial decisions, the vehicle should be evaluated by a qualified professional.
