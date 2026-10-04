class Env {
  const Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://shopeespot.vercel.app',
  );

  /// Stadia Maps API key injected via `--dart-define-from-file=env.json`.
  /// Must not be committed or hardcoded in source control.
  static const String stadiaApiKey = String.fromEnvironment('STADIA_API_KEY');
}
