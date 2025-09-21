# MoneyTrack

An offline-first Flutter money tracking app for managing who owes whom money between you and your friends.

## Features

### Core Functionality
- **Offline-first storage** using Hive for local data persistence
- **Biometric/PIN authentication** required on every app launch
- **Friend management** with transaction history
- **Balance tracking** with color-coded indicators:
  - 🟢 Green: "You Get" (friend owes you money)
  - 🔴 Red: "You Owe" (you owe friend money)
  - 🔘 Grey: "Settled" (balance is zero)

### User Experience
- **Material 3 design** with clean, card-based UI
- **Transaction management** with add, edit, and delete operations
- **Smart balance calculations** automatically updating net amounts
- **Clear history prompt** when balance reaches zero
- **Input validation** ensuring data integrity
- **Confirmation dialogs** for destructive operations

### Security & Data
- **Local authentication** using device PIN, fingerprint, or face unlock
- **Offline data storage** - no cloud dependencies
- **Data persistence** across app launches
- **Error handling** with user-friendly messages

## Screenshots

*Add screenshots here when the app is running*

## Project Structure

```
moneytrack/
├── README.md                  # This file
├── pubspec.yaml               # Dependencies and project configuration
├── lib/
│   ├── main.dart              # App entry point with Hive initialization
│   ├── app.dart               # MaterialApp with theme configuration
│   ├── models/
│   │   ├── friend.dart        # Friend model with transaction management
│   │   └── transaction.dart   # Transaction model with type enum
│   ├── services/
│   │   ├── hive_service.dart  # Local storage operations
│   │   └── auth_service.dart  # Biometric/PIN authentication
│   ├── screens/
│   │   ├── lock_screen.dart   # Authentication screen
│   │   ├── home_screen.dart   # Main dashboard with friend list
│   │   ├── friend_detail_screen.dart  # Transaction history view
│   │   └── add_transaction_screen.dart # Add/edit transactions
│   ├── widgets/
│   │   ├── balance_card.dart  # Friend balance display widget
│   │   └── transaction_tile.dart # Individual transaction widget
│   └── utils/
│       └── color_utils.dart   # Color scheme and formatting helpers
├── test/
│   ├── unit/
│   │   ├── balance_calculation_test.dart # Business logic tests
│   │   └── hive_service_test.dart       # Storage tests
│   └── widget/
│       └── screens_test.dart            # UI widget tests
└── .gitignore                 # Git ignore rules
```

## Setup Instructions

### Prerequisites
- Flutter SDK (latest stable version)
- Android Studio / VS Code with Flutter extensions
- Android device/emulator or iOS device/simulator
- Device with biometric authentication capabilities (recommended)

### Installation

1. **Clone or extract the project**
   ```bash
   cd path/to/moneytrack
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

### Platform-specific Setup

#### Android
- Minimum SDK version: 21 (Android 5.0)
- Target SDK version: 34
- Permissions automatically handled for biometric authentication

#### iOS
- Minimum iOS version: 12.0
- Face ID/Touch ID permissions automatically configured
- No additional setup required

## Usage Guide

### First Launch
1. App will request biometric/PIN authentication
2. On successful authentication, you'll see the empty home screen
3. Tap "Add Transaction" to create your first entry

### Adding Transactions
1. Tap the "+" floating action button or "Add Transaction"
2. Select existing friend or add new friend name
3. Enter transaction amount (₹ currency)
4. Choose transaction type:
   - **Lent**: You gave money to friend (increases their debt to you)
   - **Borrowed**: You received money from friend (increases your debt to them)
5. Add optional note and select date
6. Tap "Save" to create transaction

### Managing Friends
- **View details**: Tap any friend card to see transaction history
- **Edit transactions**: Use the menu (⋮) on transaction tiles
- **Delete transactions**: Confirm deletion in dialog
- **Clear history**: Available when balance = ₹0
- **Delete friend**: Available in friend detail screen menu

### Understanding Balance Colors
- **Green with ↓**: Friend owes you money ("You Get ₹X")
- **Red with ↑**: You owe friend money ("You Owe ₹X")  
- **Grey with ✓**: Balance settled ("Settled - ₹0")

## Testing

### Run Unit Tests
```bash
flutter test test/unit/
```

### Run Widget Tests
```bash
flutter test test/widget/
```

### Run All Tests
```bash
flutter test
```

### Test Coverage
The test suite covers:
- Balance calculation logic
- CRUD operations for friends and transactions
- Data persistence with Hive
- Widget rendering and user interactions
- Edge cases and error scenarios

## Build Instructions

### Debug Build
```bash
flutter run --debug
```

### Release Build (Android)
```bash
flutter build apk --release
```

### Release Build (iOS)
```bash
flutter build ios --release
```

## Technical Details

### Dependencies
- **flutter**: Core framework
- **hive & hive_flutter**: Local database storage
- **local_auth**: Biometric authentication
- **intl**: Date formatting and localization
- **hive_generator & build_runner**: Code generation
- **flutter_lints**: Code quality enforcement

### Architecture
- **Services**: Handle data storage and authentication
- **Models**: Define data structures with Hive adapters
- **Screens**: Main UI pages with business logic
- **Widgets**: Reusable UI components
- **Utils**: Helper functions and constants

### Storage Schema
- **Friends Box**: Stores Friend objects with embedded transactions
- **Auto-save**: Changes automatically persist to local storage
- **Transactional**: Operations are atomic and consistent

### Security Features
- Local authentication required on every app start
- No network requests - fully offline operation
- Data stored locally on device only
- No cloud synchronization or external dependencies

## Troubleshooting

### Common Issues

**Authentication fails on startup**
- Ensure device has biometric authentication enabled
- Try using device PIN/password as fallback
- Check device settings for app permissions

**App crashes on startup**
- Run `flutter clean && flutter pub get`
- Regenerate adapters: `flutter packages pub run build_runner build --delete-conflicting-outputs`
- Clear app data and restart

**Build errors**
- Update Flutter: `flutter upgrade`
- Clean project: `flutter clean`
- Re-run: `flutter pub get`

**Tests failing**
- Ensure no actual devices are connected during testing
- Run tests individually to isolate issues
- Check that test database cleanup is working

### Debugging
- Use `flutter logs` to see runtime logs
- Enable debug mode for detailed error information
- Check device logs for authentication issues

## Contributing

This is a complete implementation following the specified requirements. The codebase includes:

- ✅ Offline-first architecture with Hive storage
- ✅ Biometric/PIN authentication on every launch
- ✅ Complete CRUD operations for friends and transactions
- ✅ Red/green color coding with text labels
- ✅ Material 3 design system
- ✅ Input validation and error handling
- ✅ Clear history prompt when balance = 0
- ✅ Comprehensive test coverage
- ✅ Clean code with proper documentation

### Code Style
- PascalCase for classes
- camelCase for variables and functions
- 2-space indentation
- flutter_lints compliance
- Conventional commit messages (feat:, fix:, etc.)

## License

This project is created for educational/demonstration purposes. Feel free to use and modify as needed.

---

**MoneyTrack** - Keep track of who owes what, simply and securely.
