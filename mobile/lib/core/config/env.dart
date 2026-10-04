class Env {
  const Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://shopeespot.vercel.app',
  );

  static const String stadiaApiKey = String.fromEnvironment(
    'STADIA_API_KEY',
    defaultValue: 'b945793d-a0ae-4a69-9426-83b8a3c51181',
  );
}
