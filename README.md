# 🚗 EksperSiz

**AI-powered vehicle damage analysis, inspection and vehicle management application for Android.**

EksperSiz combines a Flutter mobile application, a Spring Boot backend and a dedicated FastAPI/YOLO computer-vision service to analyze vehicle photos, identify visible damage and affected parts, and generate structured AI-assisted inspection reports with repair recommendations and estimated repair costs.

Beyond damage analysis, the application includes vehicle tracking, maintenance and inspection reminders, nearby automotive services, notifications, Google authentication, usage-based AI credits, business accounts and a finalized vehicle damage assessment record workflow.

> Currently in **Google Play closed testing**. The app also includes an **AI Vehicle Assistant** powered by retrieval-augmented generation (RAG).

---

## 📱 Screenshots

<p align="center">
  <img src="docs/screenshots/home.jpeg" width="23%" />
  &nbsp;
  <img src="docs/screenshots/tracking.jpeg" width="23%" />
  &nbsp;
  <img src="docs/screenshots/report.jpeg" width="23%" />
  &nbsp;
  <img src="docs/screenshots/ai-analysis.jpeg" width="23%" />
</p>

---

## ✨ Features

### 🤖 AI Vehicle Damage Analysis
- Vehicle-photo suitability validation before analysis
- YOLO-based primary vehicle, damage and vehicle-part detection
- Damage ↔ affected-part matching using bounding-box overlap
- Deterministic severity and repair recommendations from ML results
- Gemini-powered structured inspection reports
- Location-aware estimated repair-cost ranges
- Inspection history with stored analysis results
- Report regeneration without rerunning completed computer-vision analysis
- Serverless cold-start retry handling for the AI service

### 💬 AI Vehicle Assistant
- Automotive-focused conversational assistant integrated into the mobile app
- Semantic scope and intent classification instead of a fixed question/keyword allow-list
- RAG over a curated automotive knowledge base with local multilingual embeddings and PostgreSQL/pgvector
- Evidence-grounded answers with source provenance and stricter verification for exact vehicle specifications
- Secure access to authorized user data through backend-controlled tools such as vehicles, reminders and damage history
- Clarification flow for relevant but underspecified questions instead of guessing missing details
- Out-of-scope filtering before answer generation
- 30-day trial design with a daily successful-answer quota; clarification, out-of-scope and failed requests do not consume the quota
- Bounded conversation context for follow-up questions
- Private user data is kept out of the vector knowledge base

### 📄 Vehicle Damage Assessment Record
- Create a damage assessment record from a completed inspection
- Record incident date/time, location, description and declarant information
- Save and edit the record as a draft
- Finalize the record into a read-only document
- Persist a structured snapshot of vehicle, analysis and report data
- SHA-256 content hash for the finalized snapshot
- Generate and share the finalized record as PDF

### 🚘 Vehicle Management & Tracking
- Add, edit and manage vehicle profiles
- Brand/model catalog-backed vehicle entry
- Main vehicle selection
- Mileage and maintenance records
- Date- and mileage-based reminders
- Vehicle inspection scheduling and tracking
- Unified vehicle and inspection history
- Vehicle condition overview

### 🔐 Authentication & User Services
- Email/password authentication with JWT
- Google Sign-In with server-side ID-token verification
- Email verification and password-reset flow through Brevo
- Secure token storage on mobile
- Firebase Cloud Messaging and in-app notification center
- Google Maps & Places integration for nearby automotive services
- Light / dark theme support
- Turkish / English interface

### 💳 AI Credits & Billing
- **1 free detailed AI report per month** for personal accounts
- One-time **1 / 3 / 10 analysis credit packs**
- Purchased credits do not expire
- RevenueCat purchase handling and server-side synchronization
- Credit consumption tracked per completed inspection
- Purchase/refund transaction history handled by the backend

### 🏢 Business Accounts
- OWNER / MEMBER business roles
- Shared company vehicles
- Shared inspection history
- Business-level monthly analysis quota
- Invitation and membership management
- RevenueCat-backed Business plan support

### 🔄 Production App Controls
- Backend-controlled minimum Android build policy
- Google Play in-app immediate update support
- Store fallback for required updates
- Environment-based production configuration
- Runtime secrets kept outside the repository

---

## 🛠 Tech Stack

| Layer | Technologies |
| --- | --- |
| **Mobile** | Flutter, Dart, Firebase Messaging, Google Sign-In, Google Maps, RevenueCat |
| **Backend** | Java 21, Spring Boot 4.1, Spring Security, JPA/Hibernate, Flyway, Maven |
| **AI / ML** | Python, FastAPI, Ultralytics YOLO, NumPy, Pillow |
| **Generative AI** | Google Gemini, RAG, multilingual embeddings |
| **Vector Search** | PostgreSQL + pgvector |
| **Database** | PostgreSQL |
| **External Services** | Firebase, Google Maps & Places, RevenueCat, Brevo |
| **Infrastructure** | Docker, Railway |

---

## 🏗 Architecture

```text
┌─────────────────────────────┐
│     Flutter Android App     │
└──────────────┬──────────────┘
               │ HTTPS / JWT
               ▼
┌─────────────────────────────┐
│    Spring Boot REST API     │
│  Auth · Vehicles · Billing  │
│ Inspections · Records · FCM │
│ AI Assistant · Secure Tools │
└──────┬────────┬────────┬────┘
       │        │        │
       │        │        ├────────► Google Gemini
       │        │        ├────────► Google Places
       │        │        ├────────► RevenueCat
       │        │        ├────────► Firebase / FCM
       │        │        └────────► Brevo
       │        │
       │        ▼
       │  ┌───────────────────────┐
       │  │ FastAPI AI Service    │
       │  │ YOLO + RAG planning   │
       │  └───────────────────────┘
       │
       ▼
┌─────────────────────────────┐
│ PostgreSQL + pgvector       │
└─────────────────────────────┘
```

The Spring Boot API and FastAPI AI service are containerized with Docker and deployed on **Railway**. PostgreSQL stores application data, while uploaded inspection images are handled by the backend storage layer.

Secrets, API keys and production credentials are supplied through environment variables and are not committed to the repository.

---

## 🧠 AI Pipeline

```text
Vehicle Photo
     │
     ▼
Image Suitability Validation
     │
     ▼
Primary Vehicle Detection
     │
     ▼
Damage Detection
     │
     ├── SCRATCH
     ├── DENT
     ├── CRACK
     ├── BROKEN_PART
     └── BROKEN_GLASS
     │
     ▼
Vehicle-Part Detection
     │
     ▼
Damage ↔ Part Matching
     │
     ▼
Severity + Repair Recommendation
     │
     ▼
Structured ML Result
     │
     ▼
Gemini Inspection Report
     │
     ├── Damage summary
     ├── Damage description
     ├── Repair recommendation
     └── Estimated repair-cost range
```

The production AI service first detects and crops the primary vehicle, then runs the reviewed five-class damage detector and vehicle-part detector. Class IDs are resolved from the model checkpoint names rather than a fixed numeric ordering.

`NO_VISIBLE_DAMAGE` is produced as a deterministic domain result rather than a learned damage class.

ML inference and Gemini report generation are separated. If report generation fails after successful computer-vision analysis, the stored ML result can be reused and the report can be regenerated without consuming another full analysis.

More details about dataset preparation, training and model evaluation are available in [`ai-service/README.md`](ai-service/README.md).

---

## 💳 Analysis Access Flow

```text
Completed Inspection
        │
        ▼
Detailed Report Access
        │
        ├── Personal account
        │      ├── Monthly free report available → consume free allowance
        │      └── Otherwise → consume purchased credit
        │
        └── Business vehicle
               └── Validate and consume business monthly quota
```

Credit products currently supported by the backend are `analysis_1`, `analysis_3` and `analysis_10`. Purchase grants and refunds are stored as credit transactions, and the backend prevents the same external transaction from being granted twice.

---

## 📄 Damage Assessment Record Flow

```text
Completed AI Inspection
        │
        ▼
Create Record Draft
        │
        ▼
Enter Incident / Declarant Details
        │
        ▼
Save & Edit Draft
        │
        ▼
Finalize Record
        │
        ├── Snapshot vehicle data
        ├── Snapshot AI detections
        ├── Snapshot repair recommendations
        ├── Snapshot generated report
        └── Generate SHA-256 content hash
        │
        ▼
Read-only Finalized Record
        │
        ▼
Generate / Share PDF
```

Finalized records preserve a structured snapshot of the relevant inspection state so the document is not dependent on later changes to live vehicle or report data.

---

## 🔐 Security

- JWT-based stateless authentication
- BCrypt password hashing
- Server-side Google ID-token verification
- Secure mobile token storage
- Role and business-membership authorization
- Upload MIME-type and file-signature validation
- Path-traversal protection
- Server-side billing verification and transaction deduplication
- Environment-based secrets and credentials
- Non-root backend container
- HTTPS production API

---

## 🧪 Testing

The project contains automated tests across the backend, mobile application and AI service.

- **Backend:** Spring Boot / JUnit tests for authentication, vehicles, inspections, billing, quotas, business flows, AI Assistant quota/grounding behavior and service logic
- **Mobile:** Flutter widget and service tests for important user flows
- **AI Service:** damage-analyzer tests, semantic assistant routing, RAG/evidence tests, knowledge-ingestion tests, plus model evaluation and error-analysis scripts

The project also includes protections for cases such as AI-service cold starts, repeated purchase transactions and report regeneration after a completed ML analysis.

---

## 🚀 Deployment

| Component | Deployment |
| --- | --- |
| **Android app** | Google Play closed testing |
| **Spring Boot API** | Railway / Docker |
| **FastAPI AI service** | Railway / Docker |
| **Database** | PostgreSQL |
| **Configuration** | Environment variables / Flutter dart-defines |

The Android client also checks a backend-defined minimum supported build and integrates with Google Play's in-app update mechanism for required updates.

---

## 📂 Project Structure

```text
ekspersiz/
├── src/                         # Spring Boot backend source
│   ├── main/
│   │   ├── java/
│   │   └── resources/
│   └── test/
├── mobile/                      # Flutter Android application
├── ai-service/                  # FastAPI + YOLO computer-vision service
├── docs/
│   └── screenshots/             # README / portfolio screenshots
├── Dockerfile                   # Backend container
├── docker-entrypoint.sh
├── pom.xml                      # Maven backend configuration
└── README.md
```

---

## 👨‍💻 Developer

**Görkem Ertaş**  
Software Engineer — Full-Stack Development & AI/ML
