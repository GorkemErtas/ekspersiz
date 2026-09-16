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
* 🛡 Business Membership Permissions (`OWNER`, `MEMBER`)
* 🚙 Vehicle Management
* ⭐ Main Vehicle Selection
* 🗃 Vehicle Archiving While Preserving Inspection History
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
* 🏢 Business Accounts, Employee Invitations, Employee Management, and Shared Vehicles
* 📉 Shared Daily Inspection Limits for Personal and Business Usage
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
* **PostgreSQL** stores pending registrations, verified users, business accounts, memberships, invitations, vehicles, inspections, detections, repair recommendations, report status, generated reports, subscription state, and processed billing webhook events.

---

# 🛠 Tech Stack

## Mobile

* Flutter
* Dart
* Google Maps Flutter
* Geolocator
* Flutter Secure Storage
* RevenueCat Flutter SDK

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
     ▼
Explore Nearby Automotive Services
     │
     ├── Google Places Search
     ├── Rating / Distance Information
     ├── Map Visualization
     └── Google Maps Directions
```

The ML inspection result and the Gemini report use separate statuses. If Gemini report generation temporarily fails, the completed ML analysis remains available and the report can be regenerated without running YOLO again.

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

# 💳 Subscription Architecture

The application currently includes the following plan types:

* **FREE**
* **PLUS**
* **PRO**
* **BUSINESS**

Subscription plans belong to `User`. Current personal limits are:

| Plan | Active vehicles | Daily analyses |
| --- | --- | --- |
| FREE | 1 | 3 |
| PLUS | 5 | 15 |
| PRO | Unlimited | Unlimited |

Daily usage currently counts inspections with `analysisStartedAt` within the server's current calendar day. Pending inspections that have not started analysis do not count. This is a count of inspection records, not a history of every analysis attempt.

### Business membership

There is one user identity: `User`. `BusinessAccount` stores shared company data, and `BusinessMember` connects a user to a company with an `OWNER` or `MEMBER` role. A user can belong to at most one company for the MVP.

A user with the BUSINESS subscription can create a company and becomes its OWNER. Invited members can retain their personal FREE, PLUS, or PRO subscription. Subscription plans are stored only on users.

Vehicle access follows membership automatically: users without membership use personal vehicles; members use their company's shared vehicles. A vehicle belongs to either a user or a company. Each company has a shared limit of **50 active vehicles**, regardless of its member count.

Company inspection history and access are scoped through the inspection vehicle's `BusinessAccount`. `DamageInspection.user` records the member who created the inspection for audit purposes. Each company shares a limit of **100 analyses per server calendar day**, regardless of its member count. Report regeneration does not consume another analysis slot.

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

* 📄 PDF Damage Reports
* 🎯 Larger and More Diverse Damage Detection Dataset
* 🎯 Improved Vehicle-Part Classification
* 📷 Image Quality / Retake Validation
* 🌐 Optional Live Repair Pricing / Search Grounding
* 🐳 Docker / Docker Compose Support
* ☁️ Cloud Deployment
* 🔔 Push Notifications
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
* ✅ Daily FREE and PLUS Plan Inspection Limits
* ✅ Business Accounts and Member Invitations
* ✅ Shared Business Vehicles and Company Vehicle Limit
* ✅ Company-Scoped Inspection Access and Shared Daily Inspection Limit
* ✅ Mobile Company Creation and Invitation Flow
* ✅ Owner Employee List and Membership Removal
* ✅ Flutter Mobile Application
* ✅ Inspection Result Screen
* ✅ Inspection History
* ✅ End-to-End Mobile Inspection Flow
* ✅ Apple App Store / Google Play Subscription Purchase Flow
* ✅ RevenueCat Server-Side Subscription Verification and Webhooks
* ✅ Subscription Restore and Store Management Flow

## In Progress

* 🔄 ML Model Improvements
* 🔄 Increase AI output accuracy
* 🔄 Production deployment preparation
