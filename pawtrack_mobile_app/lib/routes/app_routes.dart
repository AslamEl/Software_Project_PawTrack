import 'package:flutter/material.dart';
import '../screens/onboarding_screen.dart';
import '../screens/placeholder_screen.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/password_reset_sent_screen.dart';
import '../screens/success_screen.dart';
import '../screens/main_shell.dart';
import '../screens/map_screen.dart';
import '../screens/report_form_screen.dart';
import '../screens/report_confirmed_screen.dart';
import '../screens/dog_detail_screen.dart';
import '../screens/offer_help_screen.dart';
import '../screens/update_status_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/emergency_alert_screen.dart';
import '../screens/alert_settings_screen.dart';

class AppRoutes {
  static const splash = '/splash';
  static const onboarding1 = '/onboarding-1';
  static const onboarding2 = '/onboarding-2';
  static const onboarding3 = '/onboarding-3';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const success = '/success';
  static const resetSent = '/reset-sent';
  static const home = '/home';
  static const map = '/map';
  static const report = '/report';
  static const statusTagging = '/status-tagging';
  static const reportConfirmed = '/report-confirmed';
  static const dogDetail = '/dog-detail';
  static const offerHelp = '/offer-help';
  static const updateStatus = '/update-status';
  static const notifications = '/notifications';
  static const emergencyAlert = '/emergency-alert';
  static const alertSettings = '/alert-settings';
  static const communityFeed = '/community-feed';
  static const postStory = '/post-story';
  static const communityChat = '/community-chat';
  static const userProfile = '/user-profile';
  static const heroBadges = '/hero-badges';
  static const leaderboard = '/leaderboard';
  static const appSettings = '/app-settings';

  static final Map<String, WidgetBuilder> routes = {
    splash: (context) => const SplashScreen(),
    onboarding1: (context) => const OnboardingScreen(),
    onboarding2: (context) => const OnboardingScreen(),
    onboarding3: (context) => const OnboardingScreen(),
    login: (context) => const LoginScreen(),
    register: (context) => const RegisterScreen(),
    forgotPassword: (context) => const ForgotPasswordScreen(),
    success: (context) => const SuccessScreen(),
    resetSent: (context) => const PasswordResetSentScreen(),
    home: (context) => const MainShell(),
    map: (context) => const MapScreen(),
    report: (context) => const ReportFormScreen(),
    statusTagging: (context) => const PlaceholderScreen(title: 'Status Tagging'),
    reportConfirmed: (context) => const ReportConfirmedScreen(),
    dogDetail: (context) => const DogDetailScreen(),
    offerHelp: (context) => const OfferHelpScreen(),
    updateStatus: (context) => const UpdateStatusScreen(),
    notifications: (context) => const NotificationsScreen(),
    emergencyAlert: (context) => const EmergencyAlertScreen(),
    alertSettings: (context) => const AlertSettingsScreen(),
    communityFeed:
        (context) => const PlaceholderScreen(title: 'Community Feed'),
    postStory: (context) => const PlaceholderScreen(title: 'Post a Story'),
    communityChat:
        (context) => const PlaceholderScreen(title: 'Community Chat'),
    userProfile: (context) => const PlaceholderScreen(title: 'User Profile'),
    heroBadges: (context) => const PlaceholderScreen(title: 'Hero Badges'),
    leaderboard: (context) => const PlaceholderScreen(title: 'Leaderboard'),
    appSettings: (context) => const PlaceholderScreen(title: 'App Settings'),
  };
}
