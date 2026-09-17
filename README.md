# 🚗 EksperSiz — Vehicle Inspector

EksperSiz is an AI-powered mobile vehicle damage inspection application built with **Flutter**, **Spring Boot**, **FastAPI**, **YOLO**, **Google Gemini**, **PostgreSQL**, **Google Maps**, and **Google Places**.

The application analyzes vehicle images, detects visible damage, identifies affected vehicle parts, recommends repair actions, generates an AI-assisted inspection report, estimates a repair price range, and helps users discover nearby automotive repair services based on the inspection location.

---

# ✨ Features

* 🔐 JWT Authentication & Authorization
* ✉️ Email Verification Before Account Creation
* 🔑 Password Change Support
* 🔄 Persistent Login & Automatic Session Restoration
* 👤 User Profile & Secure Logout
* 🌗 Persistent Dark and Light Themes (Dark by Default)
* 🛡 Business Membership Permissions (`OWNER`, `MEMBER`)
* 🚙 Vehicle Management
* ⭐ Main Vehicle Selection
* 🗃 Vehicle Archiving While Preserving Inspection History
* 🔧 Vehicle Maintenance Records and Optional Cost Tracking
* 🔔 Date- and Mileage-Based Vehicle Reminders
* 🔔 Persistent In-App Notification Center and FCM Push Delivery
* 📋 Vehicle Condition Overview and Unified History Timeline
* 📍 GPS-Based Inspection Location
* 🗺 Google Maps Integration
* 📷 Camera / Gallery Vehicle Image Upload
* 🤖 YOLO-Based Damage Detection
* 🧩 Multiple Affected Vehicle Part Detection
* ⚠️ Damage Severity Classification
* 🎯 Model Confidence Scoring
* 🔧 Repair Action Recommendation
* 🧠 Gemini-Powered Inspection Reports
* 💰 Location-Aware Repair Cost Estimation
* 🔄 Retryable AI Report Generation Without Re-running YOLO
* 🔎 Nearby Automotive Service Discovery
* 🏷 Vehicle-Brand-Aware Service Recommendations
* ⭐ Google Places Ratings & Distance Information
* 🧭 Google Maps Directions to Selected Services
* 📊 Inspection History
* 💳 Subscription Plans (`FREE`, `PLUS`, `PRO`, `BUSINESS`)
* 📺 Ad-Supported FREE Plan with One Server-Verified Rewarded Analysis
* 🏢 Business Accounts, Employee Invitations, Employee Management, and Shared Vehicles
* 📉 Shared Monthly Inspection Limits for Personal and Business Usage
* 🗄 PostgreSQL Persistence
* 🌐 RESTful API
* 🔒 Secure Mobile Token Storage

---

# 🏗 Architecture

```text
Flutter Mobile Application
            │
            ▼
     Spring Boot REST API
            │
     ┌──────┼───────────────┬────────────────┐
     │      │               │                │
     ▼      ▼               ▼                ▼
PostgreSQL  FastAPI       Gemini API     Google Places
              │               │                │
         YOLO Models      AI Report       Nearby Services
              │          + Price Range        │
              ▼                               ▼
      Damage / Part Analysis             Google Maps
```

* **Flutter** provides the mobile application and complete end-to-end inspection experience.
* **Spring Boot** acts as the orchestration layer for authentication, vehicles, inspections, subscriptions, persistence, AI requests, nearby service discovery, and report lifecycle management.
* **FastAPI** performs computer-vision inference using YOLO models.
* **YOLO** detects visible damage types and affected vehicle parts.
* **Gemini** converts structured ML results into a user-friendly inspection report and estimates a repair price range based on vehicle and inspection context.
* **Google Places** is used to discover nearby automotive repair services.
* **Google Maps** visualizes service locations and opens driving directions from the user's current location.
* **PostgreSQL** stores pending registrations, verified users, business accounts, memberships, invitations, vehicles, inspections, detections, repair recommendations, report status, generated reports, subscription state, rewarded-analysis claims, notifications, device tokens, and processed billing webhook events.

---

# 🛠 Tech Stack

## Mobile

* Flutter
* Dart
* Google Maps Flutter
* Geolocator
* Flutter Secure Storage
* RevenueCat Flutter SDK
* Google Mobile Ads SDK
* Firebase Cloud Messaging

## Backend

* Java 21
* Spring Boot
* Spring Security
* Spring Data JPA
* JWT
* Spring Mail
* Maven

## AI & LLM

* Python
* FastAPI
* Ultralytics YOLO
* PyTorch
* Google Gemini API

## Maps & Location

* Google Maps SDK
* Google Places API
* Device GPS / Geolocation

## Database

* PostgreSQL

## Tools

* IntelliJ IDEA
* Android Studio
* Visual Studio Code
* Postman
* Git
* GitHub

---

# 🔄 Inspection Workflow

```text
Submit Registration Details
     │
     ▼
Email Verification
     │
     ▼
Create User Account / Login
     │
     ▼
Create / Select Vehicle
     │
     ▼
Create Inspection
+ Capture GPS Location
     │
     ▼
Upload Vehicle Image
     │
     ▼
Pre-Analysis Image Quality Check
     │
     ├── Vehicle Visibility / Framing
     ├── Excessive Blur
     └── Unusable Darkness
     │
     ├── Unsuitable → Retake (no quota reservation)
     │
     ▼
FastAPI / YOLO Analysis
     │
     ├── Damage Detection
     ├── Affected Part Detection
     ├── Damage Severity
     └── Repair Recommendation
     │
     ▼
Persist ML Results
     │
     ▼
Gemini Report Generation
     │
     ├── Human-Readable Damage Report
     ├── Repair Recommendation Explanation
     └── Location-Aware Estimated Price Range
     │
     ▼
Save Inspection Report
     │
     ▼
Display Complete Inspection Result
     │
     ├── Generate / Share Branded PDF
     │
     ▼
Explore Nearby Automotive Services
     │
     ├── Google Places Search
     ├── Rating / Distance Information
     ├── Map Visualization
     └── Google Maps Directions
```

The ML inspection result and the Gemini report use separate statuses. If Gemini report generation temporarily fails, the completed ML analysis remains available and the report can be regenerated without running YOLO again.

A successful inference with no visible damage is stored as a completed inspection with `DamageSeverity.NONE`, `DamageType.NO_VISIBLE_DAMAGE`, and `RepairAction.NO_ACTION`. It still consumes monthly analysis quota because inference was performed. Spring Boot creates its explanatory report deterministically without calling Gemini. `InspectionStatus.FAILED` is reserved for technical failures such as an unavailable AI service, timeout, invalid image, invalid AI response, or an unexpected processing error. A valid minor detection remains `MINOR` and follows the normal report flow.

Before Spring Boot reserves analysis quota, FastAPI performs a lightweight suitability check using image brightness, blur, recognizable-vehicle detection, and the detected vehicle's share of the frame. An unsuitable photo remains retryable, does not reserve quota, and does not create a failed analysis. Flutter keeps the user on the photo step with a specific retake message.

Completed results can be exported as a branded PDF and shared through the device's native share sheet. The PDF uses the stored inspection, vehicle, report, and image data. No-visible-damage PDFs omit damage and repair-price sections and retain the visible-image-only disclaimer.

---

# 🧪 AI/ML Experimentation Pipeline

The current production AI path remains:

```text
Vehicle Detection
  → Damage Object Detection
  → Vehicle Part Detection
  → Bounding-Box Overlap Matching
  → Structured Result
```

Two isolated experiments are available without changing `ai-service/models/best.pt`:

1. **Damage Detection V2** uses the empty `vehicle_damage_detection_v2` dataset structure and the existing YOLO detection base model.
2. **Damage Segmentation V1 — EXPERIMENTAL** uses a separate polygon dataset and segmentation checkpoint. Its future target is vehicle detection → damage mask → vehicle-part localization → mask/part intersection → structured result.

Both experiments share the canonical `SCRATCH`, `DENT`, `PAINT_DAMAGE`, `CRACK`, `BROKEN_PART`, `BROKEN_GLASS`, and `DEFORMATION` taxonomy. `NO_VISIBLE_DAMAGE` remains a deterministic domain result represented by clean negative images, never a learned object or mask class.

Dataset population, training commands, independent test comparison, real-world error analysis, future mask-area signals, and the manual candidate promotion process are documented in [`ai-service/README.md`](ai-service/README.md). Training and evaluation outputs remain outside production, and candidate promotion is always an explicit reviewed action.

---

# 🤖 Example Inspection Response

```json
{
  "status": "COMPLETED",
  "reportStatus": "COMPLETED",
  "reportMessage": null,
  "damageSeverity": "SEVERE",
  "damageTypes": [
    "BROKEN_PART",
    "DENT"
  ],
  "affectedParts": [
    "HEADLIGHT",
    "GRILLE",
    "FRONT_BUMPER"
  ],
  "confidenceScore": 0.9212,
  "locationCity": "Izmir",
  "repairRecommendations": [
    {
      "damageType": "BROKEN_PART",
      "recommendedAction": "PART_REPLACEMENT",
      "partReplacementRequired": true,
      "affectedParts": [
        "HEADLIGHT",
        "GRILLE",
        "FRONT_BUMPER"
      ]
    }
  ],
  "report": {
    "title": "Honda City Hasar Tespiti ve Onarım Raporu",
    "estimatedMinimumPrice": 27000.00,
    "estimatedMaximumPrice": 34000.00,
    "currency": "TRY",
    "priceInformation": "Estimated repair cost based on the vehicle, detected damage, repair requirements, and inspection location.",
    "disclaimer": "The price range is an AI-generated market estimate and is not a final service quote."
  }
}
```

---

# 🧠 AI Inspection Report & Price Estimation

After YOLO completes the vehicle damage analysis, Spring Boot sends structured inspection information to Gemini, including:

* Vehicle brand and model
* Model year
* Mileage
* Inspection location
* Damage severity
* Detected damage types
* Affected vehicle parts
* Recommended repair actions
* Part replacement requirements
* Model confidence information

Gemini uses this context to generate:

* A readable damage summary
* Detailed damage description
* Repair recommendation explanation
* Estimated minimum repair price
* Estimated maximum repair price
* Price reasoning
* A user-facing disclaimer

The current demo does **not** use live repair-shop pricing. Repair prices are AI-generated estimates based on the available vehicle, damage, repair, and location context and should not be treated as final quotations.

---

# 📍 Nearby Service Discovery

After an inspection is completed, users can explore nearby automotive services relevant to the vehicle and detected damage.

The backend integrates with **Google Places API** and returns information such as:

* Service name
* Address
* Latitude and longitude
* Google rating
* Number of user ratings
* Primary place type
* Distance from the inspection location
* Google Maps information

The Flutter application displays these services on a Google Map. Users can select a service, view its information, and open driving directions in Google Maps using their current device location.

---

# 🔧 Vehicle Companion

Each active vehicle has a detail screen for its maintenance records, reminders, current overview, and history. Maintenance entries store the maintenance type, date, mileage, optional cost and note, and calculated next recommended date or mileage. Reminders can use a date, mileage, or both and are classified as `OVERDUE`, `DUE_SOON`, `UPCOMING`, or `COMPLETED` from the current date and vehicle mileage.

Reminder inputs are type-specific and the backend owns every deterministic calculation:

* **Periodic inspection:** Turkey's Ministry of Transport rules use the conformity document's manufacture date for a new vehicle's first inspection and the approved inspection date for later periods. Private/official cars and two/three-wheeled vehicles use 3 years for the first inspection and 2 years thereafter; wheeled tractors use 3 years for both; other motor vehicles, trailers, and semi-trailers use 1 year. When category or source data is unknown, users enter the official expiry date instead of the application guessing. See the Ministry's [Vehicle Inspection Stations Regulation, Article 14](https://uhdgm.uab.gov.tr/uploads/pages/yonetmelikler/yonetmelik.pdf).
* **Traffic insurance and comprehensive insurance:** the policy's actual expiry date is stored as the due date. The application does not assume a universal one-year term because the SEDDK general conditions define coverage through the start and end dates written in the policy: [traffic insurance general conditions](https://seddk.gov.tr/upload/Sigortac%C4%B1l%C4%B1k%20Mevzuat%C4%B1/Genel%20%C5%9Eartlar/Sorumluluk%20Sigortalar%C4%B1/Karayollar%C4%B1%20Motorlu%20Ara%C3%A7lar%20Zorunlu%20Mali%20Sorumluluk%20Trafik%20Sigortas%C4%B1%20Genel%20%C5%9Eartlar%C4%B1.pdf) and [comprehensive insurance general conditions](https://seddk.gov.tr/upload/Sigortac%C4%B1l%C4%B1k%20Mevzuat%C4%B1/Genel%20%C5%9Eartlar/Mal%20Sigortalar%C4%B1/Kara%20Ara%C3%A7lar%C4%B1%20Kasko%20Sigortas%C4%B1%20Genel%20%C5%9Eartlar%C4%B1.pdf).
* **Maintenance:** users provide the last maintenance date/mileage and the manufacturer or service interval in months and/or kilometres. The backend calculates the next target. No universal maintenance interval is assumed.

The persisted source fields remain separate from the calculated due fields. The existing notification scheduler continues to use the calculated due date/mileage and its 30/7/1/0-day and mileage thresholds.

The overview combines the latest maintenance, active reminders, and latest completed AI damage inspection. Its condition label is a practical summary of stored data and is not a mechanical inspection. The history timeline combines vehicle creation, mileage updates, maintenance, and completed AI inspections without duplicating inspection records.

Tracking fields are optional during vehicle creation. Users can create a vehicle with only its core details and add maintenance or reminders later. Company members automatically read and update the same vehicle records through their shared `BusinessAccount`; the creator user is retained for audit information.

Archived vehicles remain available to history and maintenance/reminder reads, while new changes require an active vehicle.

---

# 💳 Subscription Architecture

The application currently includes the following plan types:

* **FREE**
* **PLUS**
* **PRO**
* **BUSINESS**

Subscription plans belong to `User`. Current personal limits are:

| Plan | Active vehicles | Monthly AI analyses |
| --- | --- | --- |
| FREE | 1 | 1 |
| PLUS | 3 | 5 |
| PRO | 10 | 20 |

Monthly usage counts inspections with `analysisStartedAt` inside the server's current calendar month. Pending inspections that have not started analysis do not count. Retrying the same inspection in its reserved month does not consume another slot, while a retry from an earlier month requires capacity in the current month. A completed inspection cannot be analyzed again.

FREE users can earn at most one additional analysis in each server calendar month by completing a rewarded AdMob ad. This raises the effective FREE maximum from one to two analyses for that month. Spring Boot grants the extra analysis only after validating AdMob's signed server-side verification callback; a Flutter reward callback by itself never changes quota. After the client callback, Flutter polls the quota endpoint for a short bounded period and continues the pending inspection flow only when the backend confirms the reward. PLUS, PRO, and BUSINESS users are ad-free and do not use rewarded analyses.

### Business membership

There is one user identity: `User`. `BusinessAccount` stores shared company data, and `BusinessMember` connects a user to a company with an `OWNER` or `MEMBER` role. A user can belong to at most one company for the MVP.

A user with the BUSINESS subscription can create a company and becomes its OWNER. Invited members can retain their personal FREE, PLUS, or PRO subscription. Subscription plans are stored only on users.

Vehicle access follows membership automatically: users without membership use personal vehicles; members use their company's shared vehicles. A vehicle belongs to either a user or a company. Each company has a shared limit of **50 active vehicles**, regardless of its member count.

Company inspection history and access are scoped through the inspection vehicle's `BusinessAccount`. `DamageInspection.user` records the member who created the inspection for audit purposes. Each company shares a limit of **100 analyses per server calendar month**, regardless of its member count. Report regeneration does not consume another analysis slot.

The mobile application receives this membership context through login and session restoration responses. Members automatically see the shared company vehicles and inspections; there is no personal/company workspace switch. Only BUSINESS subscribers receive company-management controls and can create a company. Owners can invite registered users, list employees by name and email, and remove employee memberships. Users without a company can accept an invitation through the separate company-invitation action, including invited FREE, PLUS, and PRO users. Regular company members do not receive company-management controls. The BUSINESS plan does not have a personal quota fallback before company membership is established.

### Registration and email verification

Submitting the registration form creates or replaces a short-lived pending registration and sends a verification code. It does not create a `User` row. A successful email verification creates the user as verified and removes the pending registration. Reopening registration with the same unverified email is therefore allowed, while an email that already belongs to a verified user cannot be registered again.

Paid plans use native Apple App Store and Google Play subscriptions through RevenueCat. The mobile application never sends a plan choice that the backend trusts. After a purchase or restore, Spring Boot reads the customer's verified RevenueCat subscription and updates the plan stored on `User`. RevenueCat webhooks keep renewals, cancellations, billing issues, refunds, product changes, and expirations synchronized. A cancellation retains access through the paid period; a refund or expiration returns the user to `FREE`.

The suggested monthly launch prices are shown below. The store console remains the source of truth for the actual localized price displayed at checkout.

| Plan | Suggested monthly price | Store product ID | RevenueCat package ID |
| --- | ---: | --- | --- |
| PLUS | ₺149.99 | `eksper_plus_monthly` | `plus_monthly` |
| PRO | ₺349.99 | `eksper_pro_monthly` | `pro_monthly` |
| BUSINESS | ₺1,499.99 | `eksper_business_monthly` | `business_monthly` |

### Payment configuration

1. Register the Android application ID and iOS bundle ID `com.gorkem.ekspersiz` in Google Play Console and App Store Connect. Update any Google Maps key restrictions to use these production identifiers.
2. Create the three auto-renewing monthly products above. Keep them in the same subscription group so customers can change tiers.
3. Connect both store applications to RevenueCat. Create one current Offering with the three custom package IDs shown above and attach each package to its matching store product.
4. Configure a RevenueCat webhook for `POST /api/v1/billing/revenuecat/webhook`. Set a private Authorization header and enable HMAC signing.
5. Supply the backend secrets as environment variables:

```text
REVENUECAT_SECRET_API_KEY=<RevenueCat secret API key>
REVENUECAT_WEBHOOK_AUTHORIZATION=Bearer <long random webhook token>
REVENUECAT_WEBHOOK_SIGNING_SECRET=<RevenueCat webhook HMAC secret>
```

6. Supply only RevenueCat's public, app-specific SDK keys to Flutter:

```bash
flutter run \
  --dart-define=REVENUECAT_ANDROID_PUBLIC_KEY=<public Android key> \
  --dart-define=REVENUECAT_IOS_PUBLIC_KEY=<public iOS key>
```

7. Configure production signing before uploading store builds. Android reads the standard ignored `mobile/android/key.properties` file with `storeFile`, `storePassword`, `keyAlias`, and `keyPassword`; configure the matching Apple signing team and provisioning profile in Xcode.

The secret RevenueCat API key and webhook secrets belong only on the Spring Boot server. The mobile app receives a random billing customer ID from the authenticated backend and uses it as the RevenueCat App User ID. Store purchase prices are loaded from RevenueCat, StoreKit, or Google Play at runtime; the TRY values in the API are display fallbacks for builds without store configuration.

The authenticated billing API is available at `GET /api/v1/billing` and `POST /api/v1/billing/sync`. The sync endpoint re-fetches the provider state instead of accepting subscription claims from the device. Webhook event IDs are persisted to make retry delivery idempotent, and webhook HMAC signatures are checked against the raw request body with a five-minute replay tolerance.

---

# Ads and Rewarded FREE Analysis

The home screen shows one lightweight banner only for personal FREE users. Ads are not shown during image selection, upload, analysis, report generation, or critical warnings. PLUS, PRO, BUSINESS subscribers, and users operating through a company membership are ad-free.

Development builds use Google's official AdMob test IDs by default. Those sample units validate the ad UI but cannot call this project's SSV endpoint. To test the complete rewarded-analysis flow securely, use the application's own rewarded unit ID, configure its SSV callback, and mark the device as a test device with the comma-separated `ADMOB_TEST_DEVICE_IDS` Dart define. The real unit remains in test mode on those devices while its SSV configuration stays under project control. Before a production release:

1. Create the Android and iOS applications, banner units, and rewarded units in AdMob.
2. Configure the rewarded unit's server-side verification callback as the public HTTPS endpoint `GET /api/v1/rewards/analysis/admob/ssv`.
3. Set Android's `ADMOB_APP_ID` in the ignored `mobile/android/local.properties` file. Replace the test `GADApplicationIdentifier` in `mobile/ios/Runner/Info.plist` through the release configuration.
4. Supply production ad-unit IDs to Flutter at build time:

```bash
flutter build apk \
  --dart-define=ADMOB_BANNER_ANDROID_ID=<banner-ad-unit-id> \
  --dart-define=ADMOB_REWARDED_ANDROID_ID=<rewarded-ad-unit-id> \
  --dart-define=ADMOB_TEST_DEVICE_IDS=<device-id-1,device-id-2>
```

Use `ADMOB_BANNER_IOS_ID` and `ADMOB_REWARDED_IOS_ID` for iOS. AdMob app IDs and ad-unit IDs are identifiers rather than server secrets, but production values should still stay in the release configuration so development continues to use test inventory.

The authenticated reward API exposes quota at `GET /api/v1/rewards/analysis` and creates a short-lived server session at `POST /api/v1/rewards/analysis/session`. An unexpired session is reused so repeated taps cannot rotate the token while an SSV callback is in flight. The SSV endpoint verifies Google's ECDSA signature, the server-issued token, customer identity, timestamp, month, and unique transaction before persisting the reward. Repeated or client-forged claims do not add quota.

---

# Notification Center and FCM

Spring Boot evaluates incomplete vehicle reminders every day at 09:00 in `Europe/Istanbul` by default. It writes persistent, idempotent notification records first; FCM is only the delivery channel. Date reminders are evaluated at 30, 7, 1, and 0 days, while mileage reminders use 2,000 km, 500 km, and due thresholds. Vehicle inspection, compulsory traffic insurance, and kasko reminders also send push notifications at 7 days, 1 day, and the due date. Each reminder/recipient/threshold combination has one unique event key, so repeated scheduler runs do not create duplicate notifications.

For a personal vehicle, the owner receives the notification. For a shared company vehicle, every current `BusinessMember` receives one personal notification record for the threshold. This gives each member independent read state and avoids duplicate records for the same member.

The authenticated notification API supports listing, unread count, marking one or all as read, and registering or removing device tokens under `/api/v1/notifications`. Flutter refreshes FCM tokens, registers them against the authenticated user, and removes the current token on logout.

Firebase console and credential setup must be completed separately before push delivery works:

1. Create or select a Firebase project, register Android and iOS apps with bundle/application ID `com.gorkem.ekspersiz`, and enable Cloud Messaging. Configure APNs credentials and Push Notifications/Background Modes for iOS.
2. Give the backend Firebase Admin credentials through Application Default Credentials or `GOOGLE_APPLICATION_CREDENTIALS`, then set `FCM_ENABLED=true`. Keep the service-account JSON outside the repository.
3. Supply the Flutter Firebase client values at build or run time:

```bash
flutter run \
  --dart-define=FIREBASE_API_KEY=<firebase-api-key> \
  --dart-define=FIREBASE_ANDROID_APP_ID=<android-app-id> \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=<sender-id> \
  --dart-define=FIREBASE_PROJECT_ID=<project-id>
```

For iOS, use `FIREBASE_IOS_APP_ID` and optionally `FIREBASE_IOS_BUNDLE_ID`. Without these client values or enabled backend credentials, the application continues to provide its persistent in-app notification center while push delivery remains disabled.

The schedule can be overridden with `NOTIFICATION_SCHEDULE_CRON` and `NOTIFICATION_TIME_ZONE`.

---

# 🔄 AI Report Retry Flow

ML analysis and LLM report generation are handled independently.

```text
ML Analysis
    │
    ├── Success → InspectionStatus.COMPLETED
    │
    ▼
Gemini Report
    │
    ├── Success → ReportStatus.COMPLETED
    │
    └── Failure → ReportStatus.FAILED
```

If Gemini fails because of a temporary API, connectivity, or quota issue, the inspection itself is not marked as failed.

The existing ML result can be reused through:

```http
POST /api/v1/inspections/{inspectionId}/report
```

This regenerates only the AI report and does not rerun the YOLO image analysis.

---

# 🔒 Security

* JWT Authentication
* BCrypt Password Hashing
* Stateless Authorization
* Business Membership Role Checks (`OWNER`, `MEMBER`)
* Email Verification
* Secure Mobile Token Storage
* Authenticated Inspection Access
* File Size and MIME-Type Validation
* Image File Signature Validation
* UUID-Based Stored File Names
* Path Traversal Protection for Uploaded Files
* Sensitive configuration values loaded through environment variables

---

# 🚀 Future Improvements

* 🎯 Larger and More Diverse Damage Detection Dataset
* 🎯 Improved Vehicle-Part Classification
* 🌐 Optional Live Repair Pricing / Search Grounding
* 🐳 Docker / Docker Compose Support
* ☁️ Cloud Deployment
* 🧪 Expanded Automated Test Coverage
* ⚙️ CI/CD Pipeline

---

# 👨‍💻 Author

**Görkem Ertaş**

Software Engineer

---

# ⭐ Project Status

🚧 **Actively under development**

## Completed

* ✅ JWT Authentication & Authorization
* ✅ User Registration & Login
* ✅ Email Verification
* ✅ Password Change
* ✅ Persistent Mobile Sessions
* ✅ Automatic Session Restoration
* ✅ User Profile & Logout
* ✅ Vehicle Management
* ✅ Main Vehicle Selection
* ✅ Vehicle Archiving
* ✅ Inspection Management
* ✅ GPS-Based Inspection Location
* ✅ AI Damage Detection
* ✅ Multiple Affected Part Detection
* ✅ Damage Severity Classification
* ✅ Repair Recommendation
* ✅ Gemini AI Report Generation
* ✅ Location-Aware Repair Price Estimation
* ✅ Persistent Inspection Reports
* ✅ AI Report Status Management
* ✅ Retryable AI Report Generation
* ✅ Google Maps Integration
* ✅ Google Places Nearby Service Search
* ✅ Vehicle-Brand-Aware Nearby Service Recommendations
* ✅ Service Ratings & Distance Display
* ✅ Google Maps Directions
* ✅ Subscription Plan Architecture
* ✅ Monthly FREE, PLUS, and PRO Plan Inspection Limits
* ✅ Business Accounts and Member Invitations
* ✅ Shared Business Vehicles and Company Vehicle Limit
* ✅ Company-Scoped Inspection Access and Shared Monthly Inspection Limit
* ✅ Mobile Company Creation and Invitation Flow
* ✅ Owner Employee List and Membership Removal
* ✅ Vehicle Maintenance Records and Optional Cost Tracking
* ✅ Date- and Mileage-Based Reminders
* ✅ Persistent In-App Notification Center
* ✅ Scheduled, Idempotent FCM Reminder Delivery
* ✅ Vehicle Condition Overview and Unified History Timeline
* ✅ Flutter Mobile Application
* ✅ Inspection Result Screen
* ✅ Inspection History
* ✅ End-to-End Mobile Inspection Flow
* ✅ Apple App Store / Google Play Subscription Purchase Flow
* ✅ RevenueCat Server-Side Subscription Verification and Webhooks
* ✅ Subscription Restore and Store Management Flow
* ✅ Ad-Supported FREE Plan and AdMob Banner Integration
* ✅ Server-Verified Rewarded FREE Analysis
* ✅ Pre-Analysis Image Quality and Retake Validation
* ✅ Branded PDF Inspection Reports and Native Sharing

## In Progress

* 🔄 ML Model Improvements
* 🔄 Increase AI output accuracy
* 🔄 Production deployment preparation
