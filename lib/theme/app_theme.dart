import 'package:flutter/material.dart';

class AppTheme {
  // Telegram-like colors
  static const Color primaryColor = Color(0xFF0088CC);
  static const Color secondaryColor = Color(0xFF5EB5F7);
  static const Color backgroundColor = Color(0xFFFFFFFF);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color dividerColor = Color(0x1F000000);
  static const Color textColor = Color(0xFF000000);
  static const Color secondaryTextColor = Color(0xFF707579);
  static const Color hintTextColor = Color(0xFFA0A0A0);
  static const Color unreadBadgeColor = Color(0xFF3B9BEC);

  // Dark theme colors
  static const Color darkBackgroundColor = Color(0xFF121212);
  static const Color darkCardColor = Color(0xFF1E1E1E);
  static const Color darkTextColor = Color(0xFFFFFFFF);
  static const Color darkSecondaryTextColor = Color(0xFFA0A0A0);
  static const Color darkDividerColor = Color(0x1FFFFFFF);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
        seedColor: primaryColor, brightness: Brightness.light);
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      dividerColor: dividerColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 1.6),
        ),
      ),
      cardTheme: const CardThemeData(
        color: cardColor,
        elevation: 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16))),
        margin: EdgeInsets.all(8),
      ),
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      snackBarTheme:
          const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      textTheme: TextTheme(
        titleLarge: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: textColor,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: secondaryTextColor,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: hintTextColor,
          fontSize: 12,
        ),
        labelLarge: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: TextStyle(
          color: secondaryTextColor,
          fontSize: 12,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: secondaryTextColor,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
        seedColor: primaryColor, brightness: Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: darkBackgroundColor,
      cardColor: darkCardColor,
      dividerColor: darkDividerColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkCardColor,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 1,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 1.6),
        ),
      ),
      cardTheme: const CardThemeData(
        color: darkCardColor,
        elevation: 1,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16))),
        margin: EdgeInsets.all(8),
      ),
      dialogTheme: const DialogThemeData(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16))),
      ),
      snackBarTheme:
          const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      textTheme: TextTheme(
        titleLarge: TextStyle(
          color: darkTextColor,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: darkTextColor,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: darkSecondaryTextColor,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: darkSecondaryTextColor,
          fontSize: 12,
        ),
        labelLarge: TextStyle(
          color: darkTextColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: TextStyle(
          color: darkSecondaryTextColor,
          fontSize: 12,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkCardColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: darkSecondaryTextColor,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
    );
  }

  // Message bubble styles
  static BoxDecoration get sentMessageBubble => BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
      );

  static BoxDecoration get receivedMessageBubble => BoxDecoration(
        color: Colors.grey[200],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      );

  // Chat list item styles
  static BoxDecoration get chatListItemDecoration => BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 0.5,
          ),
        ),
      );

  static BoxDecoration get darkChatListItemDecoration => BoxDecoration(
        color: darkCardColor,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[800]!,
            width: 0.5,
          ),
        ),
      );
}
