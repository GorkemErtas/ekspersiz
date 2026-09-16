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
* **PostgreSQL** stores pending registrations, verified users, business accounts, memberships, invitations, vehicles, inspections, detections, repair recommendations, report status, generated reports, and user subscription information.

---

# 🛠 Tech Stack

## Mobile

* Flutter
* Dart
* Google Maps Flutter
* Geolocator
* Flutter Secure Storage

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

Payment processing is not enabled in the current demo release. The first public version is intended to operate without paid subscriptions, while the subscription structure is already represented in the backend and mobile application for future expansion.

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
* 💳 Payment & Premium Subscription Integration
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

## In Progress

* 🔄 ML Model Improvements
* 🔄 Increase AI output accuracy
* 🔄 Production deployment preparation
