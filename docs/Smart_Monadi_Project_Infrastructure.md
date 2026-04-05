# Smart Monadi - Project Infrastructure

## 1. Introduction

### 1.1 Project Idea
Smart Monadi is a smart transportation coordination system built around school or student bus operations. It connects a Driver App and a Passenger App through a real-time backend to ensure every passenger is informed, visible, and handled at the right time and place.

The system combines live bus location tracking, ETA estimation, geofencing checks, and automatic SMS alerts so that passengers receive timely updates and drivers can focus on safe driving and route execution.

### 1.2 Main Objectives
- Build a reliable real-time transportation workflow between driver and passengers.
- Reduce manual coordination effort for the driver.
- Deliver accurate arrival notifications to passengers.
- Ensure pickup status is tracked automatically and consistently.
- Keep all operational data synchronized and logged in one backend source.

### 1.3 Why This Project Is Useful
- Improves punctuality and communication for daily transportation.
- Prevents missed pickups through proactive alerts and location-aware logic.
- Reduces uncertainty for passengers and families.
- Gives drivers a clearer, organized view of who is next and who has already been picked up.
- Provides transport operators with historical logs for monitoring and service quality improvement.

### 1.4 Primary Beneficiaries
- Drivers: less coordination burden and clearer trip execution.
- Passengers/Students: timely alerts and better visibility of bus arrival.
- Transport Coordinators/Schools: improved service control, accountability, and operational records.

---

## 2. System Components

### 2.1 Driver App (Flutter)

#### 2.1.1 Role
A mobile application used by the bus driver to manage route execution in real time.

#### 2.1.2 Core Functions
- Displays the current bus position in real time on Google Maps.
- Shows passengers sorted by proximity and route context.
- Receives status updates and sends operational signals through Firebase.
- Reflects notification state and pickup state for each passenger.
- Automatically marks a passenger as picked up when departure conditions are met.

#### 2.1.3 Why It Is Used
- Centralizes route visibility and passenger progress for the driver.
- Minimizes manual tracking and reduces cognitive load during operation.
- Enables immediate action based on current route conditions.

#### 2.1.4 Data It Consumes/Produces
- Consumes: live passenger status, pickup-time changes, ETA results, geofence outcomes.
- Produces: live bus GPS coordinates, pickup confirmations, route progress updates.

---

### 2.2 Passenger App (Flutter)

#### 2.2.1 Role
A mobile application for passengers/students to register information and receive trip updates.

#### 2.2.2 Core Functions
- Passenger registration with home address and phone number.
- Receives smart SMS notifications (for example, 4-5 minutes before arrival and at arrival).
- Allows pickup-time modifications.
- Pushes updated pickup preferences to Firebase in real time.

#### 2.2.3 Why It Is Used
- Gives passengers control over their pickup schedule.
- Ensures they are informed before the bus arrives.
- Reduces missed pickups caused by communication delays.

#### 2.2.4 Data It Consumes/Produces
- Consumes: ETA updates, notification status, pickup confirmation status.
- Produces: profile data, address/location data, pickup-time modifications.

---

### 2.3 Database Layer (Firebase)

#### 2.3.1 Role
The real-time data backbone for both applications.

#### 2.3.2 Supported Implementation Choices
- Firebase Realtime Database, or
- Cloud Firestore

Either option supports live synchronization between driver and passenger workflows.

#### 2.3.3 Core Stored Data
- Passenger profiles (address, phone number, preferences).
- Bus route and trip sessions.
- Live bus location updates.
- ETA and status snapshots.
- Notification history and delivery events.
- Journey logs and pickup confirmation records.

#### 2.3.4 Why It Is Used
- Enables bidirectional, low-latency updates for both apps.
- Maintains a single source of truth for operations and logs.
- Supports backend automation through Firebase Functions for event-driven processing.

---

### 2.4 SMS Notification Service (Twilio)

#### 2.4.1 Role
Sends automatic SMS alerts to passengers based on ETA/proximity logic.

#### 2.4.2 Trigger Scenarios
- Bus is estimated to arrive in 4-5 minutes.
- Bus reaches the passenger pickup zone.

#### 2.4.3 Why It Is Used
- SMS remains effective even when app foreground usage is low.
- Provides direct and immediate communication on standard phone channels.
- Increases reliability of passenger awareness at critical moments.

#### 2.4.4 Message Intent
- Upcoming arrival warning.
- Arrival confirmation at pickup point.

---

### 2.5 GPS and Google Maps

#### 2.5.1 Role
Provides real-time location capture and route/map visualization.

#### 2.5.2 Core Functions
- Continuously captures bus coordinates from GPS.
- Displays bus movement on Google Maps in the Driver App.
- Supplies route/proximity context used by ETA and geofencing modules.

#### 2.5.3 Why It Is Used
- Required for real-world movement tracking.
- Enables location-aware decision making for notifications and pickup automation.

---

### 2.6 Data Analysis and ETA Algorithms

#### 2.6.1 Role
Computes expected arrival timing and passenger processing order.

#### 2.6.2 Core Functions
- Calculates ETA per passenger using current location and route progress.
- Re-evaluates ETAs as the bus moves.
- Optimizes next-passenger order based on route alignment and proximity.

#### 2.6.3 Why It Is Used
- Supports proactive notifications.
- Helps driver prioritize stops in an organized sequence.
- Improves timing precision and service consistency.

#### 2.6.4 Inputs and Outputs
- Inputs: bus coordinates, passenger locations, route path.
- Outputs: ETA values, approach state, passenger ordering recommendations.

---

### 2.7 Geofencing

#### 2.7.1 Role
Defines geographic boundaries around each passenger pickup location.

#### 2.7.2 Core Functions
- Creates a zone (radius/boundary) around each pickup point.
- Detects when bus enters/leaves relevant passenger zones.
- Validates notification and pickup confirmation events against location boundaries.

#### 2.7.3 Why It Is Used
- Prevents false or premature notifications.
- Increases confidence that alerts and pickup status represent real events.

---

## 3. Data Flow

### 3.1 Step-by-Step Data Movement
1. The bus location is continuously updated through GPS.
2. Location updates are sent to Firebase in real time.
3. ETA and geofencing logic analyze incoming location updates.
4. SMS notifications are triggered for passengers based on proximity and ETA conditions.
5. Passenger pickup confirmation is logged automatically when departure/presence rules are satisfied.
6. Driver App is updated in real time with each passenger status and route progress.

### 3.2 Component Interaction Diagram (Simple Text)
```text
                +----------------------+
                |   GPS + Google Maps  |
                +----------+-----------+
                           |
                           | Live bus coordinates
                           v
+------------------+   +---+--------------------+   +------------------+
|   Driver App     |<->|       Firebase         |<->|  Passenger App   |
|   (Flutter)      |   | (Realtime DB/Firestore)|   |    (Flutter)     |
+--------+---------+   +---+--------------------+   +--------+---------+
         |                 ^           |
         |                 |           |
         |                 |           v
         |                 |   +----------------------+
         |                 +---| ETA + Geofencing     |
         |                     | Algorithms            |
         |                     +-----------+----------+
         |                                 |
         |                                 | Trigger SMS events
         |                                 v
         |                     +----------------------+
         +-------------------->|   SMS Service        |
                               |      (Twilio)        |
                               +----------------------+
```

### 3.3 Operational Flow Diagram (Sequence Style)
```text
GPS -> Firebase -> ETA/Geofencing -> SMS Service -> Passenger
  \                                          \
   \-> Driver App (live location/status)      \-> Firebase logs
                                               \-> Driver App pickup updates
Passenger App -> Firebase (time changes/profile updates) -> Driver App (instant sync)
```

---

## 4. Minimum Viable Product (MVP)

### 4.1 MVP Purpose
Deliver the smallest fully working system that proves the core value of Smart Monadi using only the specified technologies.

### 4.2 Mandatory MVP Features
- Real-time bus tracking through GPS and Google Maps.
- Automatic SMS notifications to passengers (pre-arrival and arrival).
- Automatic passenger pickup confirmation.
- Passenger ability to modify pickup times with immediate driver-side updates.

### 4.3 MVP Scope Discipline
The MVP focuses only on essential, must-have operational flow. It should avoid non-essential enhancements until the core loop is stable:
- Track bus
- Predict arrival
- Notify passenger
- Confirm pickup
- Sync status in real time

### 4.4 MVP Success Criteria
- Driver sees current route state and passenger statuses live.
- Passenger receives timely SMS notifications tied to actual bus movement.
- Pickup status changes happen automatically and are logged.
- Pickup-time edits from passenger are reflected to driver without delay.

---

## 5. Project Goals

### 5.1 Operational Goals
- Reduce driver workload by automating status tracking and notification logic.
- Prevent passengers from being missed or forgotten.
- Improve experience and confidence for both passengers and drivers.
- Increase timing accuracy and route organization in daily operations.

### 5.2 Quality Goals
- Real-time reliability of state synchronization.
- Consistent and correct notification timing.
- Trustworthy pickup logs for operational review.

---

## 6. Technology Stack

Only the following technologies are part of this project infrastructure:

- Flutter
Used for both Driver App and Passenger App user interfaces and mobile workflows.

- Flutter package: flutter_screenutil
Used to scale spacing, sizing, radius values, and typography across different screen dimensions so UI elements remain visually consistent on small and large devices.

- Flutter package: easy_localization
Used to provide bilingual language support (Arabic and English) and dynamic text adaptation based on selected language or device preference.

- Firebase (Realtime Database or Firestore + Functions)
Used for real-time data storage, synchronization, event-driven backend logic, and journey logs.

- Google Maps + GPS
Used for real-time bus location tracking, map visualization, and route context.

- SMS API (Twilio)
Used for automatic passenger SMS notifications triggered by ETA/proximity conditions.

- Geofencing
Used to validate location-based events and reduce false notifications.

- Data Analysis and ETA Algorithms
Used to estimate arrival times and optimize passenger servicing order.

---

## 7. Additional Notes

### 7.1 Technology Boundaries
- All implementation work should remain strictly within the listed stack.
- No external or unrelated tools/services should be introduced into core infrastructure decisions.

### 7.2 Design Consistency
- Each component must have a clear responsibility and data contract.
- Real-time synchronization should remain centralized through Firebase.
- Notification decisions must always depend on ETA and geofencing validation.

### 7.3 Documentation Purpose
This file is intended to be:
- A technical reference for developers.
- A communication artifact for project stakeholders.
- A print-ready architecture overview for planning and implementation alignment.

### 7.4 Implementation Guidance
During development, preserve the core logic order:
1. Capture live location.
2. Sync to Firebase.
3. Analyze ETA/geofencing.
4. Trigger SMS.
5. Log pickup and status.
6. Reflect updates in both apps.

Maintaining this sequence ensures predictable behavior and consistent user experience across the full system.

---

## 8. Theme Options (Dark Mode and Light Mode)

### 8.1 Theme Support Scope
The Driver App and Passenger App support both Light Mode and Dark Mode to improve readability in different lighting conditions and user contexts.

### 8.2 Automatic Theme Adaptation
- The UI can follow the device system theme setting by default.
- If the device is set to dark appearance, the app renders dark colors, surfaces, and text contrast values.
- If the device is set to light appearance, the app renders light surfaces with high readability contrast.

Why this is used:
- Aligns with user expectations and operating system behavior.
- Improves accessibility and comfort during day/night usage.
- Reduces visual fatigue for drivers and passengers in practical real-world conditions.

### 8.3 Manual Theme Switching in Flutter (Implementation Note)
Theme switching can be implemented with a theme state (for example, system/light/dark) that is stored and applied through app-level theme configuration.

Typical flow:
1. Read saved user preference from local app state.
2. If no explicit user choice exists, use system appearance mode.
3. Rebuild MaterialApp with the selected theme mode.
4. Keep both Driver and Passenger app themes aligned to shared visual identity rules.

Why this is used:
- Gives users control while preserving automatic behavior.
- Supports a consistent brand presentation in both theme modes.

### 8.4 Theme Adaptation Diagram
```text
System Theme / User Preference
        |
        v
  Theme Mode Resolver
      (system | light | dark)
        |
        v
      Flutter Theme Application
        |
        v
   Driver App UI + Passenger App UI
```

---

## 9. Screen Size Responsiveness

### 9.1 Responsiveness Strategy
The project uses flutter_screenutil to normalize UI dimensions across varying mobile screen sizes, pixel densities, and resolutions.

### 9.2 How flutter_screenutil Is Applied
- Define a base design size once.
- Scale width, height, and radius values relative to actual device dimensions.
- Scale text using responsive font sizing.
- Keep component proportions stable across device classes.

### 9.3 Why This Is Used
- Prevents layout distortion on very small or very large screens.
- Reduces manual per-device UI tuning effort.
- Keeps Driver and Passenger interfaces visually consistent, improving usability and professionalism.

### 9.4 Practical UI Impact
- Buttons keep tappable, ergonomic size.
- Spacing remains balanced and readable.
- Forms and map overlays stay proportional across devices.

---

## 10. Localization (Arabic and English)

### 10.1 Localization Scope
The project includes bilingual support using easy_localization to handle Arabic and English for:
- Screen titles and labels.
- Passenger-facing messages.
- Driver operational statuses.
- Notification text templates used by app-side messaging logic.

### 10.2 Language Adaptation Behavior
- Language can follow device locale by default.
- User can switch language from app settings.
- All localized keys are resolved at runtime so the interface updates consistently.

Why this is used:
- Enables wider usability across different user groups.
- Improves comprehension for both Arabic and English users.
- Reduces operational errors caused by language friction.

### 10.3 Right-to-Left and Left-to-Right Considerations
- Arabic screens should support RTL layout direction.
- English screens should use LTR layout direction.
- UI components should remain structurally consistent across both directions.

Why this is used:
- Preserves natural reading flow per language.
- Improves clarity in critical transportation interactions.

### 10.4 Localization Flow Diagram
```text
Selected Locale (ar/en)
    |
    v
   easy_localization Loader
    |
    v
  Localized Keys -> UI Text/Labels
    |
    v
 Driver App + Passenger App Rendered
 with correct language and direction
```

---

## 11. Architecture (MVVM + Clean Architecture)

### 11.1 Architectural Approach
Smart Monadi uses MVVM with Clean Architecture principles to enforce clear responsibility boundaries and scalable code organization.

### 11.2 MVVM Separation of Concerns
- Model
Contains data entities, data structures, and domain representations (for example passenger profile, route point, trip status, ETA output).

- View
Flutter UI screens and widgets for Driver and Passenger applications.

- ViewModel
Holds presentation/business logic for screen behavior, state transitions, and communication between View and Model.

Why MVVM is used:
- Keeps UI code cleaner by moving logic out of widgets.
- Makes state handling easier to reason about.
- Improves reusability of logic between screens.

### 11.3 Clean Architecture Layers (Conceptual)
- Presentation Layer
Views and ViewModels for UI interaction and state rendering.

- Domain Layer
Use-cases and business rules (ETA evaluation triggers, pickup confirmation rules, geofence checks).

- Data Layer
Repositories and remote data handling through Firebase, SMS integration, and map/location sources.

Why Clean Architecture is used:
- Improves maintainability by isolating changes to the correct layer.
- Improves testability because domain logic can be tested independently of UI.
- Reduces coupling between UI, backend transport, and service integrations.

### 11.4 Architecture Interaction Diagram
```text
    +----------------------+
    |   Presentation       |
    |  (View, ViewModel)   |
    +----------+-----------+
         |
         v
    +----------------------+
    |      Domain          |
    | (Use Cases/Rules)    |
    +----------+-----------+
         |
         v
    +----------------------+
    |       Data           |
    | (Firebase/SMS/Maps)  |
    +----------------------+
```

---

## 12. Visual Identity

### 12.1 Purpose
Smart Monadi defines a complete visual identity system shared across Driver and Passenger apps to ensure consistency, trust, and strong product recognition.

### 12.2 Color System
- Primary color
Used for key actions, app bars, and high-priority UI anchors.

- Secondary color
Used for supportive highlights, section grouping, and contextual emphasis.

- Accent color
Used for status emphasis such as approaching/arrived indicators and notable interactive cues.

Why color system is used:
- Creates recognizable branding.
- Helps users identify priority actions quickly.
- Improves navigation clarity in operational screens.

### 12.3 Typography and Fonts
- Define a consistent type scale for titles, body text, captions, and button labels.
- Maintain readability for both Arabic and English scripts.
- Apply clear weight hierarchy to separate primary and secondary information.

Why typography is used:
- Improves readability and scanning speed.
- Reduces user confusion in time-sensitive flows.

### 12.4 Iconography
- Use a consistent icon style for map states, notifications, passenger status, and settings.
- Keep icon semantics stable across both apps.

Why iconography is used:
- Speeds up recognition of frequent actions and statuses.
- Improves cross-language comprehension.

### 12.5 Button and Widget Styles
- Standardize button shapes, corner radius, spacing, and elevation behavior.
- Keep form inputs, cards, chips, and status badges consistent.
- Apply state styles clearly (default, pressed, disabled, success, warning).

Why standardized components are used:
- Reduces learning curve.
- Improves perceived quality and consistency.
- Makes UI maintenance and extension easier.

### 12.6 Unified UX Language Across Driver and Passenger Apps
- Shared design tokens and component behavior rules across both applications.
- Preserve role-specific differences while retaining a common visual grammar.

Why this is used:
- Ensures both apps feel like one integrated platform.
- Strengthens trust, branding, and usability across the full transportation workflow.

### 12.7 Current UI Implementation Snapshot (April 2026)
- A shared Design System is implemented in code through reusable primitives and tokens:
  - Gradient header cards.
  - Section cards.
  - Status pills.
  - Timeline tiles.
  - Shared spacing/radius/motion/palette tokens.
- A unified loading language is implemented via reusable skeleton components instead of ad-hoc progress indicators.
- Driver, Passenger, Operations, and Auth screens now consume the same visual primitives for higher consistency.
- Navigation is responsive:
  - Mobile uses bottom NavigationBar.
  - Wide layouts use NavigationRail for better information density and desktop/tablet ergonomics.

Why this matters:
- Reduces UI duplication and styling drift.
- Speeds up feature delivery because new screens can reuse established components.
- Improves maintainability and visual quality across future iterations.

---

## 13. Integration Notes for New Additions

### 13.1 Alignment with Existing Stack
The added capabilities are integrated within the current stack and flow:
- Flutter (Driver and Passenger Apps): hosts theming, responsive UI, localization, and MVVM presentation layer.
- Firebase (Realtime Database/Firestore + Functions): remains the real-time data backbone and event automation source.
- Google Maps + GPS: continues to provide live location and route context.
- SMS API (Twilio): remains responsible for delivery of automated passenger SMS alerts.
- Data Analysis and ETA Algorithms: continue to evaluate arrival timing and ordering.
- Geofencing: continues to validate location boundaries for correct trigger behavior.

### 13.2 Cross-Cutting Integration Mapping
- Theme system affects all UI screens without changing backend logic.
- Responsiveness applies to layout rendering for all screen modules.
- Localization affects text rendering and language-dependent UX direction.
- MVVM + Clean Architecture structures how the same existing business features are implemented and tested.

### 13.3 Integrated Runtime View
```text
Flutter Apps (Driver/Passenger)
  |- Theme (Light/Dark)
  |- Responsive UI (flutter_screenutil)
  |- Localization (easy_localization)
  |- MVVM Presentation
   |
   v
Domain Rules (ETA + Geofencing + Pickup Logic)
   |
   v
Data Layer (Firebase + Maps/GPS + Twilio)
```

Why this integration model is used:
- Adds usability and architecture improvements without replacing core technologies.
- Keeps existing transportation logic stable while improving maintainability and user experience.
