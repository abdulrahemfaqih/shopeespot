import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum NavigationApp {
  googleMaps('Google Maps'),
  waze('Waze');

  const NavigationApp(this.label);
  final String label;
}

const prefNavigationAppKey = 'pref_navigation_app';

typedef LaunchUrlFn = Future<bool> Function(Uri url, {LaunchMode mode});

class NavigationLauncher {
  NavigationLauncher({LaunchUrlFn? launchUrlFn})
    : _launchUrlFn = launchUrlFn ?? launchUrl;

  final LaunchUrlFn _launchUrlFn;

  Uri buildPrimaryUri(NavigationApp app, double latitude, double longitude) {
    switch (app) {
      case NavigationApp.googleMaps:
        return Uri.parse('google.navigation:q=$latitude,$longitude&mode=l');
      case NavigationApp.waze:
        return Uri.parse('waze://?ll=$latitude,$longitude&navigate=yes');
    }
  }

  Uri buildFallbackUri(NavigationApp app, double latitude, double longitude) {
    switch (app) {
      case NavigationApp.googleMaps:
        return Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&travelmode=two-wheeler',
        );
      case NavigationApp.waze:
        return Uri.parse(
          'https://waze.com/ul?ll=$latitude,$longitude&navigate=yes',
        );
    }
  }

  Future<bool> launch({
    required double latitude,
    required double longitude,
    NavigationApp app = NavigationApp.googleMaps,
  }) async {
    final primaryUri = buildPrimaryUri(app, latitude, longitude);
    try {
      final launched = await _launchUrlFn(
        primaryUri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return true;
    } catch (_) {
      // Ignore and proceed to fallback
    }

    final fallbackUri = buildFallbackUri(app, latitude, longitude);
    try {
      final fallbackLaunched = await _launchUrlFn(
        fallbackUri,
        mode: LaunchMode.externalApplication,
      );
      return fallbackLaunched;
    } catch (_) {
      return false;
    }
  }
}

final navigationLauncherProvider = Provider<NavigationLauncher>((ref) {
  return NavigationLauncher();
});

class NavigationAppNotifier extends Notifier<NavigationApp> {
  @override
  NavigationApp build() {
    _loadFromPrefs();
    return NavigationApp.googleMaps;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(prefNavigationAppKey);
    if (saved != null) {
      if (saved == NavigationApp.waze.name) {
        state = NavigationApp.waze;
      } else {
        state = NavigationApp.googleMaps;
      }
    }
  }

  Future<void> setApp(NavigationApp app) async {
    state = app;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefNavigationAppKey, app.name);
  }
}

final navigationAppProvider =
    NotifierProvider<NavigationAppNotifier, NavigationApp>(
      NavigationAppNotifier.new,
    );
