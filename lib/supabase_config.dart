/// Values de conexión inyectados al compilar o ejecutar Flutter.
/// Usa la clave anon/publishable del proyecto; nunca pongas aquí una service key.
class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://kpnfdotjgtppntkiffih.supabase.co',
  );
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtwbmZkb3RqZ3RwcG50a2lmZmloIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzMzI3NDcsImV4cCI6MjEwNTkwODc0N30.n87GO1RNPcEbFrFbwMfR87TT6Xe4awJ_lQVJJgmgSLw',
  );

  static bool get configured => url.isNotEmpty && anonKey.isNotEmpty;
}
