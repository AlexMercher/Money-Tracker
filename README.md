# MoneyTracker<<<<<<< HEAD

# MoneyTrack

An offline-first Flutter money tracking app for managing who owes whom money between you and your friends.

An offline-first Flutter money tracking app for managing who owes whom money between you and your friends.

## Features

## Features

### Core Functionality

- **Offline-first storage** using Hive for local data persistence### Core Functionality

- **Biometric/PIN authentication** required on every app launch- **Offline-first storage** using Hive for local data persistence

- **Friend management** with transaction history- **Biometric/PIN authentication** required on every app launch

- **Balance tracking** with color-coded indicators:- **Friend management** with transaction history

  - 🟢 Green: "You Get" (friend owes you money)- **Balance tracking** with color-coded indicators:

  - 🔴 Red: "You Owe" (you owe friend money)  - 🟢 Green: "You Get" (friend owes you money)

  - 🔘 Grey: "Settled" (balance is zero)  - 🔴 Red: "You Owe" (you owe friend money)

  - 🔘 Grey: "Settled" (balance is zero)

### User Experience

- **Material 3 design** with clean, card-based UI### User Experience

- **Transaction management** with add, edit, and delete operations- **Material 3 design** with clean, card-based UI

- **Smart balance calculations** automatically updating net amounts- **Transaction management** with add, edit, and delete operations

- **Clear history prompt** when balance reaches zero- **Smart balance calculations** automatically updating net amounts

- **Input validation** ensuring data integrity- **Clear history prompt** when balance reaches zero

- **Confirmation dialogs** for destructive operations- **Input validation** ensuring data integrity

- **Confirmation dialogs** for destructive operations

### Security & Data

- **Local authentication** using device PIN, fingerprint, or face unlock### Security & Data

- **Offline data storage** - no cloud dependencies- **Local authentication** using device PIN, fingerprint, or face unlock

- **Data persistence** across app launches- **Offline data storage** - no cloud dependencies

- **Error handling** with user-friendly messages- **Data persistence** across app launches

- **Error handling** with user-friendly messages

## Screenshots

## Screenshots

*Add screenshots here when the app is running*

*Add screenshots here when the app is running*

## Project Structure

## Project Structure

```

moneytrack/```

├── README.md                  # This filemoneytrack/

├── pubspec.yaml               # Dependencies and project configuration├── README.md                  # This file

├── lib/├── pubspec.yaml               # Dependencies and project configuration

│   ├── main.dart              # App entry point with Hive initialization├── lib/

│   ├── app.dart               # MaterialApp with theme configuration│   ├── main.dart              # App entry point with Hive initialization

│   ├── models/│   ├── app.dart               # MaterialApp with theme configuration

│   │   ├── friend.dart        # Friend model with transaction management│   ├── models/

│   │   └── transaction.dart   # Transaction model with type enum│   │   ├── friend.dart        # Friend model with transaction management

│   ├── services/│   │   └── transaction.dart   # Transaction model with type enum

│   │   ├── hive_service.dart  # Local storage operations│   ├── services/

│   │   └── auth_service.dart  # Biometric/PIN authentication│   │   ├── hive_service.dart  # Local storage operations

│   ├── screens/│   │   └── auth_service.dart  # Biometric/PIN authentication

│   │   ├── lock_screen.dart   # Authentication screen│   ├── screens/

│   │   ├── home_screen.dart   # Main dashboard with friend list│   │   ├── lock_screen.dart   # Authentication screen

│   │   ├── friend_detail_screen.dart  # Transaction history view│   │   ├── home_screen.dart   # Main dashboard with friend list

│   │   └── add_transaction_screen.dart # Add/edit transactions│   │   ├── friend_detail_screen.dart  # Transaction history view

│   ├── widgets/│   │   └── add_transaction_screen.dart # Add/edit transactions

│   │   ├── balance_card.dart  # Friend balance display widget│   ├── widgets/

│   │   └── transaction_tile.dart # Individual transaction widget│   │   ├── balance_card.dart  # Friend balance display widget

│   └── utils/│   │   └── transaction_tile.dart # Individual transaction widget

│       └── color_utils.dart   # Color scheme and formatting helpers│   └── utils/

├── test/│       └── color_utils.dart   # Color scheme and formatting helpers

│   ├── unit/├── test/

│   │   ├── balance_calculation_test.dart # Business logic tests│   ├── unit/

│   │   └── hive_service_test.dart       # Storage tests│   │   ├── balance_calculation_test.dart # Business logic tests

│   └── widget/│   │   └── hive_service_test.dart       # Storage tests

│       └── screens_test.dart            # UI widget tests│   └── widget/

└── .gitignore                 # Git ignore rules│       └── screens_test.dart            # UI widget tests

```└── .gitignore                 # Git ignore rules

```

## Setup Instructions

## Setup Instructions

### Prerequisites

- Flutter SDK (latest stable version)### Prerequisites

- Android Studio / VS Code with Flutter extensions- Flutter SDK (latest stable version)

- Android device/emulator or iOS device/simulator- Android Studio / VS Code with Flutter extensions

- Device with biometric authentication capabilities (recommended)- Android device/emulator or iOS device/simulator

- Device with biometric authentication capabilities (recommended)

### Installation

### Installation

1. **Clone or extract the project**

   ```bash1. **Clone or extract the project**

   cd path/to/moneytrack   ```bash

   ```   cd path/to/moneytrack

   ```

2. **Install dependencies**

   ```bash2. **Install dependencies**

   flutter pub get   ```bash

   ```   flutter pub get

   ```

3. **Generate Hive adapters**

   ```bash3. **Generate Hive adapters**

   flutter packages pub run build_runner build   ```bash

   ```   flutter packages pub run build_runner build

   ```

4. **Run the app**

   ```bash4. **Run the app**

   flutter run   ```bash

   ```   flutter run

   ```

### Platform-specific Setup

### Platform-specific Setup

#### Android

- Minimum SDK version: 21 (Android 5.0)#### Android

- Target SDK version: 34- Minimum SDK version: 21 (Android 5.0)

- Permissions automatically handled for biometric authentication- Target SDK version: 34

- Permissions automatically handled for biometric authentication

#### iOS

- Minimum iOS version: 12.0#### iOS

- Face ID/Touch ID permissions automatically configured- Minimum iOS version: 12.0

- No additional setup required- Face ID/Touch ID permissions automatically configured

- No additional setup required

## Usage Guide

## Usage Guide

### First Launch

1. App will request biometric/PIN authentication### First Launch

2. On successful authentication, you'll see the empty home screen1. App will request biometric/PIN authentication

3. Tap "Add Transaction" to create your first entry2. On successful authentication, you'll see the empty home screen

3. Tap "Add Transaction" to create your first entry

### Adding Transactions

1. Tap the "+" floating action button or "Add Transaction"### Adding Transactions

2. Select existing friend or add new friend name1. Tap the "+" floating action button or "Add Transaction"

3. Enter transaction amount (₹ currency)2. Select existing friend or add new friend name

4. Choose transaction type:3. Enter transaction amount (₹ currency)

   - **Lent**: You gave money to friend (increases their debt to you)4. Choose transaction type:

   - **Borrowed**: You received money from friend (increases your debt to them)   - **Lent**: You gave money to friend (increases their debt to you)

5. Add optional note and select date   - **Borrowed**: You received money from friend (increases your debt to them)

6. Tap "Save" to create transaction5. Add optional note and select date

6. Tap "Save" to create transaction

### Managing Friends

- **View details**: Tap any friend card to see transaction history### Managing Friends

- **Edit transactions**: Use the menu (⋮) on transaction tiles- **View details**: Tap any friend card to see transaction history

- **Delete transactions**: Confirm deletion in dialog- **Edit transactions**: Use the menu (⋮) on transaction tiles

- **Clear history**: Available when balance = ₹0- **Delete transactions**: Confirm deletion in dialog

- **Delete friend**: Available in friend detail screen menu- **Clear history**: Available when balance = ₹0

- **Delete friend**: Available in friend detail screen menu

### Understanding Balance Colors

- **Green with ↓**: Friend owes you money ("You Get ₹X")### Understanding Balance Colors

- **Red with ↑**: You owe friend money ("You Owe ₹X")  - **Green with ↓**: Friend owes you money ("You Get ₹X")

- **Grey with ✓**: Balance settled ("Settled - ₹0")- **Red with ↑**: You owe friend money ("You Owe ₹X")  

- **Grey with ✓**: Balance settled ("Settled - ₹0")

## Testing

## Testing

### Run Unit Tests

```bash### Run Unit Tests

flutter test test/unit/```bash

```flutter test test/unit/

```

### Run Widget Tests

```bash### Run Widget Tests

flutter test test/widget/```bash

```flutter test test/widget/

```

### Run All Tests

```bash### Run All Tests

flutter test```bash

```flutter test

```

### Test Coverage

The test suite covers:### Test Coverage

- Balance calculation logicThe test suite covers:

- CRUD operations for friends and transactions- Balance calculation logic

- Data persistence with Hive- CRUD operations for friends and transactions

- Widget rendering and user interactions- Data persistence with Hive

- Edge cases and error scenarios- Widget rendering and user interactions

- Edge cases and error scenarios

## Build Instructions

## Build Instructions

### Debug Build

```bash### Debug Build

flutter run --debug```bash

```flutter run --debug

```

### Release Build (Android)

```bash### Release Build (Android)

flutter build apk --release```bash

```flutter build apk --release

```

### Release Build (iOS)

```bash### Release Build (iOS)

flutter build ios --release```bash

```flutter build ios --release

```

## Technical Details

## Technical Details

### Dependencies

- **flutter**: Core framework### Dependencies

- **hive & hive_flutter**: Local database storage- **flutter**: Core framework

- **local_auth**: Biometric authentication- **hive & hive_flutter**: Local database storage

- **intl**: Date formatting and localization- **local_auth**: Biometric authentication

- **hive_generator & build_runner**: Code generation- **intl**: Date formatting and localization

- **flutter_lints**: Code quality enforcement- **hive_generator & build_runner**: Code generation

- **flutter_lints**: Code quality enforcement

### Architecture

- **Services**: Handle data storage and authentication### Architecture

- **Models**: Define data structures with Hive adapters- **Services**: Handle data storage and authentication

- **Screens**: Main UI pages with business logic- **Models**: Define data structures with Hive adapters

- **Widgets**: Reusable UI components- **Screens**: Main UI pages with business logic

- **Utils**: Helper functions and constants- **Widgets**: Reusable UI components

- **Utils**: Helper functions and constants

### Storage Schema

- **Friends Box**: Stores Friend objects with embedded transactions### Storage Schema

- **Auto-save**: Changes automatically persist to local storage- **Friends Box**: Stores Friend objects with embedded transactions

- **Transactional**: Operations are atomic and consistent- **Auto-save**: Changes automatically persist to local storage

- **Transactional**: Operations are atomic and consistent

### Security Features

- Local authentication required on every app start### Security Features

- No network requests - fully offline operation- Local authentication required on every app start

- Data stored locally on device only- No network requests - fully offline operation

- No cloud synchronization or external dependencies- Data stored locally on device only

- No cloud synchronization or external dependencies

## Troubleshooting

## Troubleshooting

### Common Issues

### Common Issues

**Authentication fails on startup**

- Ensure device has biometric authentication enabled**Authentication fails on startup**

- Try using device PIN/password as fallback- Ensure device has biometric authentication enabled

- Check device settings for app permissions- Try using device PIN/password as fallback

- Check device settings for app permissions

**App crashes on startup**

- Run `flutter clean && flutter pub get`**App crashes on startup**

- Regenerate adapters: `flutter packages pub run build_runner build --delete-conflicting-outputs`- Run `flutter clean && flutter pub get`

- Clear app data and restart- Regenerate adapters: `flutter packages pub run build_runner build --delete-conflicting-outputs`

- Clear app data and restart

**Build errors**

- Update Flutter: `flutter upgrade`**Build errors**

- Clean project: `flutter clean`- Update Flutter: `flutter upgrade`

- Re-run: `flutter pub get`- Clean project: `flutter clean`

- Re-run: `flutter pub get`

**Tests failing**

- Ensure no actual devices are connected during testing**Tests failing**

- Run tests individually to isolate issues- Ensure no actual devices are connected during testing

- Check that test database cleanup is working- Run tests individually to isolate issues

- Check that test database cleanup is working

### Debugging

- Use `flutter logs` to see runtime logs### Debugging

- Enable debug mode for detailed error information- Use `flutter logs` to see runtime logs

- Check device logs for authentication issues- Enable debug mode for detailed error information

- Check device logs for authentication issues

## Contributing

## Contributing

This is a complete implementation following the specified requirements. The codebase includes:

This is a complete implementation following the specified requirements. The codebase includes:

- ✅ Offline-first architecture with Hive storage

- ✅ Biometric/PIN authentication on every launch- ✅ Offline-first architecture with Hive storage

- ✅ Complete CRUD operations for friends and transactions- ✅ Biometric/PIN authentication on every launch

- ✅ Red/green color coding with text labels- ✅ Complete CRUD operations for friends and transactions

- ✅ Material 3 design system- ✅ Red/green color coding with text labels

- ✅ Input validation and error handling- ✅ Material 3 design system

- ✅ Clear history prompt when balance = 0- ✅ Input validation and error handling

- ✅ Comprehensive test coverage- ✅ Clear history prompt when balance = 0

- ✅ Clean code with proper documentation- ✅ Comprehensive test coverage

- ✅ Clean code with proper documentation

### Code Style

- PascalCase for classes### Code Style

- camelCase for variables and functions- PascalCase for classes

- 2-space indentation- camelCase for variables and functions

- flutter_lints compliance- 2-space indentation

- Conventional commit messages (feat:, fix:, etc.)- flutter_lints compliance

- Conventional commit messages (feat:, fix:, etc.)

## License

## License

This project is created for educational/demonstration purposes. Feel free to use and modify as needed.

This project is created for educational/demonstration purposes. Feel free to use and modify as needed.

---

---

**MoneyTracker** - Keep track of who owes what, simply and securely.
**MoneyTrack** - Keep track of who owes what, simply and securely.
=======
# Money-Tracker
>>>>>>> 585a4b26725f98ff8e53d538cad54c42ab6c6732
