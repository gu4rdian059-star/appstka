/// Loader stub untuk platform Web (Browser).
/// Pada Web, file `.env` TIDAK dibundel ke dalam publik `assets/` agar
/// kredensial rahasia (Brevo API Key, SMTP Password, Supabase URL/Key)
/// tidak dapat diunduh publik melalui `http://<host>/assets/.env`.
Future<Map<String, String>> loadLocalEnvFile() async {
  return const <String, String>{};
}

