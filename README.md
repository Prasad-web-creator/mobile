# Claim Support - Mobile App

This is the cross-platform mobile application for Claim Support, built with Flutter.

## Architecture

- **Framework**: Flutter (Dart)
- **State Management**: Riverpod
- **Networking**: Dio
- **Platforms**: Android, iOS

## Getting Started

### Prerequisites

- Flutter SDK (latest stable release)
- Android Studio (for Android emulation) or Xcode (for iOS simulation)
- An active backend server running locally or remotely

### Installation

1. Navigate to the mobile app directory:
   ```bash
   cd mobile-app
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```

### Running the App

To run the app on a connected device or emulator:
```bash
flutter run
```

## Structure
- `/lib/screens` - UI views for the application
- `/lib/widgets` - Reusable UI components
- `/lib/models` - Data models mapping backend responses
- `/lib/services` - API integration using Dio
- `/lib/providers` - Riverpod state providers
- `/android` & `/ios` - Native platform configuration folders

> **Note**: Build artifacts, plugins, and generated code are ignored by Git. Do not commit local properties or keystores to the repository.
## Policy Pal component gallery

Open `/debug/components` in a debug build, or launch the Android gallery directly with:

```powershell
adb shell am start -a android.intent.action.VIEW -d "claimsupport://policy-pal/debug/components" com.example.claimsupport
```

The gallery uses sample records. Use its Light and Dark controls to compare the same specimens. The review preview uses 1.3× text. Hold an interactive specimen to inspect its pressed state.

### Backend fields used by the component kit

| API field | Component | Values and fallback |
|---|---|---|
| `GET /api/analysis/grouped`: `prescription.diagnosis`, `prescription.patientName`, `createdAt` | Check card and row | Strings may be empty, missing or extraction placeholders. Diagnosis falls back to “Prescription”. Omit absent patient/date. Parse the timestamp as local time and format Today, Yesterday, d MMM or d MMM yyyy. |
| Group `status` and `policyReports[].overallStatus` | Check card, row, dot and pill | Pending/queued/extracting/analyzing/reanalyzing show Checking…. Failed checks use ?Check failed? unless a policy failure reports an extraction stage, which uses ?Couldn?t read?. Covered, Partially Covered and Not Covered (including underscore forms) map to the three approved labels. Further known outcomes and unknown non-empty labels use neutral styling. Unknown values are logged. Missing results remain neutral. |
| `policyReports[].policyId`, `policyName`, `insuranceCompany`, `reportId` and `comparisonSummary.bestPolicyId` | Check metadata, stack and policy switcher | The array can be empty, the best policy can be absent or unmatched, and names/IDs can be empty. A single policy uses its name or insurer. Use Best only for an explicit matching ID. Keep report IDs for routing and omit absent text. |
| `GET /api/dashboard`: `totalPrescriptions`, `totalPolicies` | Document card | Nonnegative counts display 0, 1–99 or 99+. Missing dashboard data shows a skeleton. |
| `GET /api/prescriptions`: `diagnosis`, `originalFileName`, `patientName`, `visitDate`, `createdAt`, `processingStatus` | Prescription row | Optional title or metadata, with “Prescription” as title fallback. Dates can be strings or null. Pending and processing display Reading…. Failed uses the extraction copy. Unknown non-empty processing states log and fall back to a neutral label. |
| `GET /api/policies`: `policyName`, `insuranceCompany`, `policyEndDate`, `status`, `processingStatus` | Policy row | Optional name and insurer, and a nullable string/date end date. Fall back to “Policy”. An explicit expired status or a valid end date before today displays Expired. Unknown processing states follow the prescription fallback. The component renders one stored record per row. Deduplication belongs to the list/data layer. |

The grouped check response does not expose a reliable document type or a tie flag. An absent or unmatched best-policy ID produces no Best tag. Static components such as buttons, sheet layouts and step indicators take presentation inputs.
