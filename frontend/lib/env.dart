class Environment {
  static const String apiUrl = String.fromEnvironment(
    'API_URL', 
    defaultValue: 'https://bpsc-saathi.onrender.com',
  );
}