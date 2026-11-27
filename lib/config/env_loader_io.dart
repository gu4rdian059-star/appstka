import 'dart:io';

/// Loader `.env` berbasis `dart:io` khusus untuk lingkungan non-Web
/// (Unit Test, Desktop, Mobile Native, atau CLI Server).
/// Membaca `.env` langsung dari sistem file tanpa mempublikasikannya di `pubspec.yaml` assets.
Future<Map<String, String>> loadLocalEnvFile() async {
  final result = <String, String>{};
  try {
    final candidates = [
      File('.env'),
      File('../.env'),
    ];
    for (final file in candidates) {
      if (await file.exists()) {
        final lines = await file.readAsLines();
        for (final rawLine in lines) {
          final line = rawLine.trim();
          if (line.isEmpty || line.startsWith('#')) continue;
          final idx = line.indexOf('=');
          if (idx <= 0) continue;
          final key = line.substring(0, idx).trim();
          var val = line.substring(idx + 1).trim();
          if ((val.startsWith('"') && val.endsWith('"')) ||
              (val.startsWith("'") && val.endsWith("'"))) {
            val = val.substring(1, val.length - 1);
          }
          result[key] = val;
        }
        break;
      }
    }
  } catch (_) {}
  return result;
}

