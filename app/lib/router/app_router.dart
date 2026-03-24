import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/onboarding/onboarding_screen.dart';
import '../screens/onboarding/pair_device_screen.dart';
import '../screens/onboarding/add_pet_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/map/live_map_screen.dart';
import '../screens/map/track_replay_screen.dart';
import '../screens/geofence/geofence_list_screen.dart';
import '../screens/geofence/geofence_editor_screen.dart';
import '../screens/geofence/geofence_history_screen.dart';
import '../screens/activity/activity_screen.dart';
import '../screens/activity/activity_detail_screen.dart';
import '../screens/health/health_screen.dart';
import '../screens/health/health_report_screen.dart';
import '../screens/health/anomaly_alert_screen.dart';
import '../screens/find_pet/find_pet_screen.dart';
import '../screens/device/device_screen.dart';
import '../screens/device/device_settings_screen.dart';
import '../screens/device/firmware_update_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/account_screen.dart';
import '../screens/settings/privacy_screen.dart';
import '../screens/settings/notification_settings_screen.dart';
import '../screens/settings/data_export_screen.dart';
import '../screens/multi_pet/pet_switcher_screen.dart';

// Route names
class Routes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const onboarding = '/onboarding';
  static const pairDevice = '/onboarding/pair-device';
  static const addPet = '/onboarding/add-pet';
  static const home = '/home';
  static const liveMap = '/map/live';
  static const trackReplay = '/map/replay';
  static const geofenceList = '/geofences';
  static const geofenceEditor = '/geofences/editor';
  static const geofenceHistory = '/geofences/history';
  static const activity = '/activity';
  static const activityDetail = '/activity/detail';
  static const health = '/health';
  static const healthReport = '/health/report';
  static const anomalyAlert = '/health/anomaly';
  static const findPet = '/find-pet';
  static const device = '/device';
  static const deviceSettings = '/device/settings';
  static const firmwareUpdate = '/device/firmware';
  static const settings = '/settings';
  static const account = '/settings/account';
  static const privacy = '/settings/privacy';
  static const notificationSettings = '/settings/notifications';
  static const dataExport = '/settings/data-export';
  static const petSwitcher = '/pets';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final settings = ref.watch(settingsProvider);

  return GoRouter(
    initialLocation: Routes.splash,
    redirect: (context, state) {
      final isAuth = authState.isAuthenticated;
      final isLoading = authState.status == AuthStatus.initial ||
          authState.status == AuthStatus.loading;

      if (isLoading) return Routes.splash;

      final isAuthRoute = state.matchedLocation == Routes.login ||
          state.matchedLocation == Routes.register ||
          state.matchedLocation == Routes.forgotPassword;

      if (!isAuth && !isAuthRoute && state.matchedLocation != Routes.splash) {
        return Routes.login;
      }

      if (isAuth && isAuthRoute) {
        return Routes.home;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.pairDevice,
        builder: (context, state) => const PairDeviceScreen(),
      ),
      GoRoute(
        path: Routes.addPet,
        builder: (context, state) => const AddPetScreen(),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.liveMap,
        builder: (context, state) => const LiveMapScreen(),
      ),
      GoRoute(
        path: Routes.trackReplay,
        builder: (context, state) => const TrackReplayScreen(),
      ),
      GoRoute(
        path: Routes.geofenceList,
        builder: (context, state) => const GeofenceListScreen(),
      ),
      GoRoute(
        path: Routes.geofenceEditor,
        builder: (context, state) {
          final geofenceId = state.uri.queryParameters['id'];
          return GeofenceEditorScreen(geofenceId: geofenceId);
        },
      ),
      GoRoute(
        path: Routes.geofenceHistory,
        builder: (context, state) {
          final geofenceId = state.uri.queryParameters['id'] ?? '';
          return GeofenceHistoryScreen(geofenceId: geofenceId);
        },
      ),
      GoRoute(
        path: Routes.activity,
        builder: (context, state) => const ActivityScreen(),
      ),
      GoRoute(
        path: Routes.activityDetail,
        builder: (context, state) => const ActivityDetailScreen(),
      ),
      GoRoute(
        path: Routes.health,
        builder: (context, state) => const HealthScreen(),
      ),
      GoRoute(
        path: Routes.healthReport,
        builder: (context, state) => const HealthReportScreen(),
      ),
      GoRoute(
        path: Routes.anomalyAlert,
        builder: (context, state) => const AnomalyAlertScreen(),
      ),
      GoRoute(
        path: Routes.findPet,
        builder: (context, state) => const FindPetScreen(),
      ),
      GoRoute(
        path: Routes.device,
        builder: (context, state) => const DeviceScreen(),
      ),
      GoRoute(
        path: Routes.deviceSettings,
        builder: (context, state) => const DeviceSettingsScreen(),
      ),
      GoRoute(
        path: Routes.firmwareUpdate,
        builder: (context, state) => const FirmwareUpdateScreen(),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.account,
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: Routes.privacy,
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        path: Routes.notificationSettings,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),
      GoRoute(
        path: Routes.dataExport,
        builder: (context, state) => const DataExportScreen(),
      ),
      GoRoute(
        path: Routes.petSwitcher,
        builder: (context, state) => const PetSwitcherScreen(),
      ),
    ],
  );
});
