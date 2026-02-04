# MoneyTrack

[![Download APK](https://img.shields.io/github/v/release/AlexMercher/Money-Tracker?label=Download%20APK&color=success)](https://github.com/AlexMercher/Money-Tracker/releases/latest)
[![License: CC BY-NC 4.0](https://img.shields.io/badge/License-CC%20BY--NC%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc/4.0/)
[![Flutter Version](https://img.shields.io/badge/Flutter-3.9+-blue.svg)](https://flutter.dev)

An offline-first Flutter application for tracking personal expenses and managing debts between friends. All data is stored locally on your device with no cloud dependencies.

---

## Features

Track expenses, manage friend debts with split transactions, set monthly budgets with visual analytics, export PDF reports, and secure your data with biometric authentication — all completely offline.

---

## Installation

### Prerequisites

- Flutter SDK ^3.9.0
- Android Studio / VS Code with Flutter extensions
- Android device/emulator or iOS device/simulator

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/AlexMercher/Money-Tracker.git
   cd Money-Tracker
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate Hive adapters**
   ```bash
   flutter packages pub run build_runner build
   ```

4. **Run the app**
   ```bash
   flutter run
   ```

### Build Commands

| Command | Description |
|---------|-------------|
| `flutter run --debug` | Run in debug mode |
| `flutter build apk --release` | Build release APK for Android |
| `flutter build ios --release` | Build release for iOS |
| `flutter build web` | Build for web |

---

## Usage

### First Launch

1. Open the app — you'll see the home screen with empty state
2. Tap **Profile** in the drawer to set your name and UPI ID (for PDF exports)
3. Start adding transactions!

### Adding Transactions

1. Tap the **+** button on the home screen
2. Select or add a friend's name
3. Enter amount (supports math expressions like `100+50*2`)
4. Choose transaction type: **Lent** (they owe you) or **Borrowed** (you owe them)
5. Add an optional note and date
6. Tap **Save**

### Split Transactions

1. Choose **Split Transaction** from the add menu
2. Enter total amount paid
3. Select friends and assign amounts
4. Use calculator buttons for quick calculations
5. Save — transactions are created for each friend automatically

### Managing Friends

- **View details**: Tap any friend card
- **View transaction**: Tap any transaction for read-only details
- **Delete**: Use the menu (⋮) on transaction tiles
- **Clear history**: Available when balance reaches zero
- **Export PDF**: Generate transaction reports with payment info

### Setting a Budget

1. Go to **Profile** → Set monthly budget
2. View spending analytics on home screen
3. Track weekly and monthly spending with charts

### Security Settings

1. Go to **Settings** → Enable **Biometric Authentication**
2. Choose when to require authentication (app launch, sensitive actions, or both)
3. Supports fingerprint, face recognition, or device PIN/password

---

## Configuration

### App Settings

Access settings via the drawer menu to configure:

| Setting | Description |
|---------|-------------|
| **Biometric Auth** | Enable/disable fingerprint/face login |
| **Require Initial Auth** | Require auth when opening app |
| **Require Sensitive Auth** | Require auth for delete/clear operations |
| **Theme** | Light, Dark, or System default |
| **Monthly Budget** | Set spending limit |
| **Carry Budget Forward** | Keep budget when month changes |

### User Profile

Configure your profile for PDF exports:

- **Name**: Your full name
- **Phone**: Contact number
- **UPI ID**: For payment requests in PDFs

---

## Architecture

### Project Structure

```
lib/
├── main.dart              # App entry point
├── app.dart               # Theme configuration & MaterialApp
├── models/                # Data models with Hive adapters
│   ├── friend.dart        # Friend entity with transactions
│   ├── transaction.dart   # Transaction entity
│   ├── user.dart          # User profile
│   ├── shadow_event.dart  # Budget tracking events
│   └── cash_ledger_entry.dart  # Cash borrowing tracking
├── services/              # Business logic & data access
│   ├── hive_service.dart  # Local storage operations
│   ├── auth_service.dart  # Biometric authentication
│   ├── theme_service.dart # Theme management
│   ├── pdf_service.dart   # PDF generation
│   └── category_service.dart  # Category management
├── screens/               # UI pages
│   ├── home_screen.dart
│   ├── add_transaction_screen.dart
│   ├── split_transaction_screen.dart
│   ├── friend_detail_screen.dart
│   ├── settings_screen.dart
│   └── ...
├── widgets/               # Reusable UI components
│   ├── balance_card.dart
│   ├── transaction_tile.dart
│   └── self_expense_charts.dart
├── utils/                 # Utilities
│   ├── budget_logic.dart
│   ├── expression_parser.dart
│   ├── color_utils.dart
│   └── constants.dart
└── logic/                 # Business logic helpers
    └── friend_logic.dart
```

### Storage Schema

Data is stored locally using [Hive](https://hivedb.dev/) NoSQL database:

| Box | Purpose |
|-----|---------|
| **friends** | Friend objects with embedded transactions |
| **user_profile** | User name, phone, UPI ID |
| **shadow_ledger** | Budget tracking events |
| **cash_ledger** | Cash borrowing/repayment records |

### Key Dependencies

| Package | Purpose |
|---------|---------|
| `hive` | Local NoSQL database |
| `local_auth` | Biometric authentication |
| `pdf` | PDF generation |
| `provider` | State management |
| `fl_chart` | Charts and graphs |
| `intl` | Date formatting |
| `shared_preferences` | Settings persistence |

---

This project is licensed under [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/) — Attribution-NonCommercial 4.0 International.

Credit: Himanshu Ranjan

---

**MoneyTrack** — Keep track of who owes what, simply and securely.
