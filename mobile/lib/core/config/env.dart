class Env {
  const Env._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );

  static const String cartoApiKey = String.fromEnvironment(
    'CARTO_API_KEY',
    defaultValue: 'cb1_4940_1_cc980a6361494a0ef3e15f93',
  );
}
