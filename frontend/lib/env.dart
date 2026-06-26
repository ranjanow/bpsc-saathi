/// Compile-time environment configuration.
///
/// For local development, leave API_URL unset (auto-detects localhost:8080).
/// For production builds, pass:
///   flutter build web --dart-define=API_URL=https://bpsc-saathi.onrender.com
class Environment {
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: '',
  );
}