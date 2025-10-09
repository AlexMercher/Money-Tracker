# MoneyTrack

An offline-first Flutter money tracking app for managing who owes whom money between you and your friends.

## Features

### Core Functionality

- **Offline-first storage** using Hive for local data persistence

- **Friend management** with transaction history-

- **Balance tracking** with color-coded indicators:- 

  - 🟢 Green: "You Get" (friend owes you money)

  - 🔴 Red: "You Owe" (you owe friend money)  

  - 🔘 Grey: "Settled" (balance is zero)  


### User Experience

- **Material 3 design** with clean, card-based UI### User Experience

- **Transaction management** with add, edit, and delete operations

- **Smart balance calculations** automatically updating net amounts

- **Clear history prompt** when balance reaches zero

- **Input validation** ensuring data integrity

- **Confirmation dialogs** for destructive operations


### Security & Data

- **Offline data storage** - no cloud dependencies

- **Data persistence** across app launchess

- **Error handling** with user-friendly messages

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

### Prerequisites

- Flutter SDK (latest stable version)### Prerequisites

- Android Studio / VS Code with Flutter extensions- Flutter SDK (latest stable version)

- Android device/emulator or iOS device/simulator- Android Studio / VS Code with Flutter extensions

- Device with biometric authentication capabilities (recommended)- Android device/emulator or iOS device/simulator

- Device with biometric authentication capabilities (recommended)

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

## Usage Guide


Tap "Add Transaction" to create your first entry


### Adding Transactions

1. Tap the "+" floating action button or "Add Transaction"### Adding Transactions

2. Select existing friend or add new friend name
3. 
4. Enter transaction amount (₹ currency)

5. Choose transaction type:)

   - **Lent**: You gave money to friend (increases their debt to you)4. Choose transaction type:

   - **Borrowed**: You received money from friend (increases your debt to them)   - **Lent**: You gave money to friend (increases their debt to you)

6. Add optional note and select date   

7. Tap "Save" to create transaction

6. Tap "Save" to create transaction

### Managing Friends

- **View details**: Tap any friend card to see transaction history### Managing Friends

- **Edit transactions**: Use the menu (⋮) on transaction tiles

- **Delete transactions**: Confirm deletion in dialog

- **Clear history**: Available when balance = ₹0
  
- **Delete friend**: Available in friend detail screen menu


### Understanding Balance Colors

- **Green with ↓**: Friend owes you money ("You Get ₹X")

- **Red with ↑**: You owe friend money ("You Owe ₹X") 

- **Grey with ✓**: Balance settled ("Settled - ₹0")

### Debug Build

```bash### Debug Build

flutter run --debug

```

### Release Build (Android)

```bash### Release Build (Android)

flutter build apk --release

```

### Release Build (iOS)

```bash### Release Build (iOS)

flutter build ios --release

```

## Technical Details


### Dependencies

- **flutter**: Core framework### Dependencies

- **hive & hive_flutter**: Local database storage

- **intl**: Date formatting and localization
  
- **hive_generator & build_runner**: Code generation

- **flutter_lints**: Code quality enforcement

### Architecture

- **Services**: Handle data storage and authentication### Architecture

- **Models**: Define data structures with Hive adapters

- **Screens**: Main UI pages with business logic

- **Widgets**: Reusable UI components

- **Utils**: Helper functions and constants

- **Utils**: Helper functions and constants

### Storage Schema

- **Friends Box**: Stores Friend objects with embedded transactions### Storage Schema

- **Auto-save**: Changes automatically persist to local storage
  
- **Transactional**: Operations are atomic and consistent

### Security Features

- No network requests - fully offline operation

- Data stored locally on device only

- No cloud synchronization or external dependencies


**Build errors**

- Update Flutter: `flutter upgrade`

- Clean project: `flutter clean`

- Re-run: `flutter pub get`

**MoneyTracker** - Keep track of who owes what, simply and securely.
=======
