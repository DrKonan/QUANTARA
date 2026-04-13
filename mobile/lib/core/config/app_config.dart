abstract class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const cinetpayApiKey = String.fromEnvironment('CINETPAY_API_KEY');
}
