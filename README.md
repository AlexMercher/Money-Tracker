# MoneyTrack

[![Download APK](https://img.shields.io/github/v/release/AlexMercher/Money-Tracker?label=Download%20APK&color=success)](https://github.com/AlexMercher/Money-Tracker/releases/latest)

An offline-first Flutter money tracking app for managing who owes whom money between you and your friends.

## Features

### Core Functionality
- **Offline-first storage** using Hive for local data persistence
- **Friend management** with transaction history
- **Balance tracking** with color-coded indicators (Green: You Get, Red: You Owe, Grey: Settled)
- **Split transactions** among multiple friends with equal or custom amounts
- **Mathematical expressions** in amount fields (e.g., 20+30*2, 100/2-10) with calculator buttons
- **Friend autocomplete** with real-time suggestions and duplicate prevention
- **Transaction search** within friend details by note or amount
- **Clear debt** with one-tap settlement transaction
- **PDF export** with transaction history, payment details, and polite reminder message
- **Transaction grouping** for duplicate transactions with expandable details
- **Read-only transaction view** showing all fields (amount, type, date, note) when tapped
- **Biometric authentication** with PIN/password fallback for app security

### User Experience
- **Material 3 design** with light/dark theme support (default: light mode)
- **Smooth page transitions** with optimized fade and slide animations
- **Empty state animation** with elastic bounce effect
- **Transaction management** with add and delete operations
- **Smart balance calculations** automatically updating net amounts
- **Clear history prompt** when balance reaches zero
- **Input validation** ensuring data integrity and preventing duplicates
- **Confirmation dialogs** for destructive operations

### Security & Data
- **Offline data storage** - no cloud dependencies
- **Biometric authentication** support (fingerprint, face recognition)
- **Device credential fallback** when biometrics unavailable
- **Data persistence** across app launches
- **Error handling** with user-friendly messages

## Technical Details

### Dependencies
- **flutter**: Core framework
- **hive & hive_flutter**: Local database storage
- **intl**: Date formatting and localization
- **local_auth**: Biometric authentication
- **shared_preferences**: Settings persistence
- **pdf & printing**: PDF generation and preview
- **path_provider**: File system access
- **permission_handler**: Storage permissions
- **open_file**: PDF file opening
- **provider**: State management
- **hive_generator & build_runner**: Code generation

### Architecture
- **Services**: Handle data storage, authentication, PDF generation, and theme management
- **Models**: Define data structures with Hive adapters
- **Screens**: Main UI pages with business logic
- **Widgets**: Reusable UI components
- **Utils**: Helper functions, constants, color utilities, expression parser, and page transitions

### Storage Schema
- **Friends Box**: Stores Friend objects with embedded transactions
- **User Profile Box**: Stores user name, phone, and UPI ID for PDF exports
- **Theme Preferences**: Stores light/dark mode selection
- **Auth Preferences**: Stores biometric authentication settings
- **Auto-save**: Changes automatically persist to local storage

## Setup Instructions

### Prerequisites
- Flutter SDK (latest stable version)
- Android Studio / VS Code with Flutter extensions
- Android device/emulator or iOS device/simulator
- Device with biometric authentication capabilities (recommended)

### Installation
1. Clone or extract the project
2. Run `flutter pub get` to install dependencies
3. Run `flutter packages pub run build_runner build` to generate Hive adapters
4. Run `flutter run` to launch the app

### Build Commands
- **Debug**: `flutter run --debug`
- **Release APK**: `flutter build apk --release`
- **Release iOS**: `flutter build ios --release`

## Usage Guide

### Adding Transactions
1. Tap the "+" floating action button
2. Select existing friend or add new friend name
3. Enter transaction amount (supports expressions like 100+50*2)
4. Choose transaction type (Lent or Borrowed)
5. Add optional note and select date
6. Tap "Save" to create transaction

### Split Transactions
1. Select "Split Transaction" from the add menu
2. Enter total amount paid
3. Toggle between equal split or manual amounts
4. Add friends and assign individual amounts (with expression support)
5. Use calculator buttons (+, -, *, /) for quick calculations
6. Each friend's transaction shows full split details in the note

### Managing Friends
- **View details**: Tap any friend card to see transaction history
- **View transaction**: Tap any transaction to see all details in read-only mode
- **Delete transactions**: Use the menu (⋮) on transaction tiles
- **Clear history**: Available when balance = ₹0
- **Export PDF**: Generate and share transaction reports with payment info

### Security Settings
- Enable biometric authentication from Settings
- Set initial authentication requirement
- Authentication required for sensitive operations (clear debt, delete data)

**MoneyTrack** - Keep track of who owes what, simply and securely.