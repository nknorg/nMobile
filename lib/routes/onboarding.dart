import 'package:flutter/material.dart';
import 'package:nmobile/routes/routes.dart';
import 'package:nmobile/screens/onboarding/seed_pin_enhanced.dart';
import 'package:nmobile/screens/onboarding/profile_setup.dart';

void init() {
  Routes.registerRoutes({
    FirstWelcomeScreen.routeName: (BuildContext context, {arguments}) =>
        FirstWelcomeScreen(),
    ProfileSetupScreen.routeName: (BuildContext context, {arguments}) =>
        ProfileSetupScreen(),
  });
}
