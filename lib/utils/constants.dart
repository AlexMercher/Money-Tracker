/// App-wide constants for better performance and maintainability
class AppConstants {
  // Animation Durations
  static const Duration fabAnimationDuration = Duration(milliseconds: 600);
  static const Duration themeTransitionDuration = Duration(milliseconds: 500);
  static const Duration emptyStateBounce = Duration(milliseconds: 2000);
  static const Duration pageTransitionDuration = Duration(milliseconds: 400);
  static const Duration fadeTransitionDuration = Duration(milliseconds: 350);
  static const Duration summaryCardAnimation = Duration(milliseconds: 700);
  static const Duration expansionTileAnimation = Duration(milliseconds: 200);
  static const Duration cardTapAnimation = Duration(milliseconds: 300);
  
  // Padding & Spacing
  static const double defaultPadding = 16.0;
  static const double cardPadding = 12.0;
  static const double largePadding = 32.0;
  static const double smallSpacing = 8.0;
  static const double mediumSpacing = 16.0;
  static const double largeSpacing = 24.0;
  
  // Border Radius
  static const double cardBorderRadius = 12.0;
  static const double buttonBorderRadius = 12.0;
  static const double chipBorderRadius = 8.0;
  
  // Icon Sizes
  static const double smallIconSize = 20.0;
  static const double mediumIconSize = 30.0;
  static const double largeIconSize = 60.0;
  static const double emptyStateIconSize = 120.0;
  
  // Text Limits
  static const int maxNoteWords = 5;
  static const int maxNoteLength = 100;
  
  // Colors (Primary)
  static const int primaryColorValue = 0xFF2E7D32;
  static const int secondaryColorValue = 0xFFFF5722;
  
  // Hive Box Names
  static const String friendsBox = 'friends';
  static const String transactionsBox = 'transactions';
  static const String userProfileBox = 'user_profile';
  static const String themeBox = 'theme_preferences';
  static const String authBox = 'auth_preferences';
  
  // PDF
  static const String pdfFolderName = 'MoneyTrack_PDFs';
  
  // Validation
  static const double minTransactionAmount = 0.01;
  static const double maxTransactionAmount = 99999999.99;
}
