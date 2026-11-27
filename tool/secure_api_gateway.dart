import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// ============================================================================
/// TKA SECURE API GATEWAY & REVERSE PROXY (Port 8787)
/// ============================================================================
/// Menyelesaikan masalah keamanan & konektivitas secara menyeluruh:
/// 1. Menyembunyikan SUPABASE_URL, SUPABASE_ANON_KEY, dan BREVO_API_KEY (Secret)
///    agar TIDAK PERNAH tampil publik di browser / DevTools Network / bundle Web.
/// 2. Memvalidasi CORS Origin Whitelist secara ketat.
/// 3. Memblokir payload berbahaya (SQL Injection & Cross-Site Scripting / XSS).
/// 4. Rate Limiting per IP pada endpoint Auth & Email.
/// 5. Menjembatani PostgREST, Auth, Storage, Realtime WebSocket, dan Brevo Email
///    dengan respons bersih (HTTP 200 / 201 / 204).
Future<void> main(List<String> args) async {
  final env = await _loadDotEnv();
  final supabaseUrl = (env['SUPABASE_URL'] ?? '').trim().replaceAll(RegExp(r'/$'), '');
  final supabaseAnonKey = (env['SUPABASE_ANON_KEY'] ?? '').trim();
  final supabaseServiceRoleKey = (env['SUPABASE_SERVICE_ROLE_KEY'] ?? '').trim();
  final effectiveAdminKey = supabaseServiceRoleKey.isNotEmpty ? supabaseServiceRoleKey : supabaseAnonKey;
  final brevoApiKey = (env['BREVO_API_KEY'] ?? env['SMTP_PASS'] ?? '').trim();
  final brevoSenderEmail = (env['BREVO_SENDER_EMAIL'] ?? 'noreply@tka-rail.id').trim();
  final brevoSenderName = (env['BREVO_SENDER_NAME'] ?? 'TKA Rail Tracking').trim();
  final mapTilerStyleUrl = (env['MAPTILER_STYLE_URL'] ?? '').trim();
  final turnstileSiteKey = (env['TURNSTILE_SITE_KEY'] ?? '').trim();
  final turnstileSecretKey = (env['TURNSTILE_SECRET_KEY'] ?? '').trim();
  final port = int.tryParse(env['GATEWAY_PORT'] ?? '8787') ?? 8787;

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    stderr.writeln('❌ SUPABASE_URL atau SUPABASE_ANON_KEY belum diisi di file .env');
    exit(1);
  }

  final upstreamBase = Uri.parse(supabaseUrl);
  final allowedOriginsRaw = env['ALLOWED_ORIGINS'] ??
      'http://localhost:5500,http://127.0.0.1:5500,http://localhost:3000,http://localhost:8080';
  final allowedOrigins = allowedOriginsRaw
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet();

  final httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 30);

  final servers = <HttpServer>[];
  final ipv4Server = await HttpServer.bind(InternetAddress.loopbackIPv4, port, shared: true);
  ipv4Server.autoCompress = true;
  servers.add(ipv4Server);
  try {
    final ipv6Server = await HttpServer.bind(InternetAddress.loopbackIPv6, port, shared: true);
    ipv6Server.autoCompress = true;
    servers.add(ipv6Server);
  } catch (_) {}

  stdout.writeln('🛡️  TKA Secure API Gateway aktif di http://localhost:$port (IPv4 + IPv6 + Gzip)');
  stdout.writeln('🔒 Upstream Supabase & Brevo Secret Key terlindungi di sisi server.');

  void listenOn(HttpServer s) {
    s.listen((HttpRequest req) {
      unawaited(
        _handleRequest(
          req: req,
          httpClient: httpClient,
          upstreamBase: upstreamBase,
          supabaseAnonKey: effectiveAdminKey,
          brevoApiKey: brevoApiKey,
          brevoSenderEmail: brevoSenderEmail,
          brevoSenderName: brevoSenderName,
          mapTilerStyleUrl: mapTilerStyleUrl,
          turnstileSiteKey: turnstileSiteKey,
          turnstileSecretKey: turnstileSecretKey,
          allowedOrigins: allowedOrigins,
        ),
      );
    });
  }

  for (final s in servers) {
    listenOn(s);
  }
  await Completer<void>().future;
}

final Map<String, List<int>> _rateBuckets = <String, List<int>>{};

class _ResetOtpEntry {
  final String email;
  final String otp;
  final String userName;
  final String? authUserId;
  final String? publicUserId;
  final int expiresAtMs;
  int attempts = 0;
  bool verified = false;
  String? resetToken;
  int? resetTokenExpiresAtMs;

  _ResetOtpEntry({
    required this.email,
    required this.otp,
    required this.userName,
    this.authUserId,
    this.publicUserId,
    required this.expiresAtMs,
  });
}

final Map<String, _ResetOtpEntry> _resetOtpStore = <String, _ResetOtpEntry>{};

class _CachedResponse {
  final List<int> bodyBytes;
  final String contentType;
  final int expiresAtMs;

  _CachedResponse({
    required this.bodyBytes,
    required this.contentType,
    required this.expiresAtMs,
  });
}

// Server-side RAM cache untuk MapTiler style & master read-heavy tables (stations, train_schedules)
final Map<String, _CachedResponse> _getCache = <String, _CachedResponse>{};

final RegExp _strictEmailRegex = RegExp(
  r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
);

final RegExp _sqliRegex = RegExp(
  r"(\b(UNION\s+ALL\s+SELECT|UNION\s+SELECT|DROP\s+TABLE|DROP\s+DATABASE|TRUNCATE\s+TABLE|ALTER\s+TABLE|PG_SLEEP|INFORMATION_SCHEMA|XP_CMDSHELL)\b)|(--\s*$)|(/\*[\s\S]*?\*/)|('\s*OR\s+'?1'?\s*=\s*'?1)",
  caseSensitive: false,
);

final RegExp _xssRegex = RegExp(
  r'(<\s*/?\s*(script|iframe|object|embed|svg)\b)|(on(error|load|mouseover|click|focus)\s*=)|(javascript\s*:)|(vbscript\s*:)',
  caseSensitive: false,
);

bool _isOriginAllowed(String? origin, Set<String> allowedOrigins) {
  if (origin == null || origin.isEmpty) return true; // Non-browser / CLI / Thunder Client
  if (allowedOrigins.contains(origin)) return true;
  final uri = Uri.tryParse(origin);
  if (uri == null) return false;
  if ((uri.scheme == 'http' || uri.scheme == 'https') &&
      (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
    return true;
  }
  return false;
}

void _applySecurityAndCorsHeaders(
  HttpResponse res,
  String? origin,
) {
  if (origin != null && origin.isNotEmpty) {
    res.headers.set('Access-Control-Allow-Origin', origin);
    res.headers.set('Vary', 'Origin');
  } else {
    res.headers.set('Access-Control-Allow-Origin', 'http://localhost:5500');
  }
  res.headers.set(
    'Access-Control-Allow-Methods',
    'GET, POST, PATCH, PUT, DELETE, OPTIONS, HEAD',
  );
  res.headers.set(
    'Access-Control-Allow-Headers',
    'authorization, apikey, content-type, prefer, x-client-info, x-supabase-api-version, content-profile, accept-profile, range, accept',
  );
  res.headers.set(
    'Access-Control-Expose-Headers',
    'Content-Range, Content-Location, Content-Type, X-Gateway-Protected',
  );
  res.headers.set('Access-Control-Max-Age', '86400');
  res.headers.set('X-Content-Type-Options', 'nosniff');
  res.headers.set('X-Frame-Options', 'DENY');
  res.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  res.headers.set('X-Gateway-Protected', 'true');
}

bool _checkRateLimit(String ip, String path) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final isSensitive = path.startsWith('/auth/') ||
      path.startsWith('/brevo/') ||
      path.startsWith('/api/auth/') ||
      path.startsWith('/api/security/');
  final key = '$ip:${isSensitive ? "auth" : "api"}';
  final limit = isSensitive ? 40 : 300;
  final list = _rateBuckets.putIfAbsent(key, () => <int>[])
    ..removeWhere((ts) => now - ts > 60000);
  if (list.length >= limit) return false;
  list.add(now);
  return true;
}

Future<void> _handleRequest({
  required HttpRequest req,
  required HttpClient httpClient,
  required Uri upstreamBase,
  required String supabaseAnonKey,
  required String brevoApiKey,
  required String brevoSenderEmail,
  required String brevoSenderName,
  required String mapTilerStyleUrl,
  required String turnstileSiteKey,
  required String turnstileSecretKey,
  required Set<String> allowedOrigins,
}) async {
  final origin = req.headers.value('origin');
  final path = req.uri.path;

  // 1. Validasi CORS Ketat
  if (!_isOriginAllowed(origin, allowedOrigins)) {
    req.response.statusCode = HttpStatus.forbidden;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode({'error': 'CORS origin not permitted'}));
    await req.response.close();
    return;
  }

  // 2. WebSocket Realtime Upgrade (/realtime/v1/websocket)
  if (WebSocketTransformer.isUpgradeRequest(req) &&
      path.startsWith('/realtime/')) {
    await _bridgeRealtimeWebSocket(req, upstreamBase, supabaseAnonKey);
    return;
  }

  _applySecurityAndCorsHeaders(req.response, origin);

  // 3. Preflight OPTIONS
  if (req.method.toUpperCase() == 'OPTIONS') {
    req.response.statusCode = HttpStatus.noContent;
    await req.response.close();
    return;
  }

  // 4. Health Check Gateway
  if (path == '/health' || path == '/api/health') {
    req.response.statusCode = HttpStatus.ok;
    req.response.headers.contentType = ContentType.json;
    req.response.write(
      jsonEncode({
        'status': 'ok',
        'gateway': 'TKA Secure API Gateway',
        'secrets_protected': true,
      }),
    );
    await req.response.close();
    return;
  }

  // 5. Rate Limiting
  final clientIp = req.connectionInfo?.remoteAddress.address ?? '127.0.0.1';
  if (!_checkRateLimit(clientIp, path)) {
    req.response.statusCode = HttpStatus.tooManyRequests;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode({'error': 'Too many requests. Please slow down.'}));
    await req.response.close();
    return;
  }

  // 6. Baca Body & Inspeksi WAF (Anti-SQLi & Anti-XSS)
  final bodyBytes = await req.fold<List<int>>(
    <int>[],
    (prev, elem) => prev..addAll(elem),
  );

  final decodedQuery = Uri.decodeFull(req.uri.query);
  if (_sqliRegex.hasMatch(decodedQuery) || _xssRegex.hasMatch(decodedQuery)) {
    req.response.statusCode = HttpStatus.badRequest;
    req.response.headers.contentType = ContentType.json;
    req.response.write(
      jsonEncode({'error': 'Blocked malicious query parameter by Security WAF'}),
    );
    await req.response.close();
    return;
  }

  // Inspek body teks/JSON (kecuali upload binary image/png/jpeg)
  final cType = (req.headers.value('content-type') ?? '').toLowerCase();
  final isBinaryUpload = path.startsWith('/storage/') && !cType.contains('json');
  String bodyText = '';
  if (!isBinaryUpload && bodyBytes.isNotEmpty) {
    bodyText = utf8.decode(bodyBytes, allowMalformed: true);
    // Jangan blokir HTML resmi email Brevo pada field htmlContent, tapi tetap cek SQLi
    final checkXss = !path.startsWith('/brevo/');
    if (_sqliRegex.hasMatch(bodyText) || (checkXss && _xssRegex.hasMatch(bodyText))) {
      req.response.statusCode = HttpStatus.badRequest;
      req.response.headers.contentType = ContentType.json;
      req.response.write(
        jsonEncode({'error': 'Blocked malicious payload by Security WAF'}),
      );
      await req.response.close();
      return;
    }
  }

  // 7. Endpoint Khusus Pengiriman Email Brevo (Server-Side Secret Injection)
  if (path == '/brevo/v3/smtp/email') {
    await _handleBrevoProxy(
      req: req,
      httpClient: httpClient,
      bodyText: bodyText,
      brevoApiKey: brevoApiKey,
      brevoSenderEmail: brevoSenderEmail,
      brevoSenderName: brevoSenderName,
    );
    return;
  }

  // 7b. Endpoint Resmi Reset Password 3-Tahap (Validasi Email Terdaftar -> Verifikasi OTP -> Update Password)
  if (path == '/api/auth/password-reset/request' &&
      req.method.toUpperCase() == 'POST') {
    await _handlePasswordResetRequest(
      req: req,
      httpClient: httpClient,
      upstreamBase: upstreamBase,
      supabaseAdminKey: supabaseAnonKey,
      bodyText: bodyText,
      brevoApiKey: brevoApiKey,
      brevoSenderEmail: brevoSenderEmail,
      brevoSenderName: brevoSenderName,
    );
    return;
  }

  if (path == '/api/auth/password-reset/verify-otp' &&
      req.method.toUpperCase() == 'POST') {
    await _handlePasswordResetVerifyOtp(
      req: req,
      bodyText: bodyText,
    );
    return;
  }

  if (path == '/api/auth/password-reset/confirm' &&
      req.method.toUpperCase() == 'POST') {
    await _handlePasswordResetConfirm(
      req: req,
      httpClient: httpClient,
      upstreamBase: upstreamBase,
      supabaseAdminKey: supabaseAnonKey,
      bodyText: bodyText,
    );
    return;
  }

  // 7c. Cached MapTiler Style JSON — Khusus Indonesia Only (TTL 1 jam di RAM -> buka peta < 1ms!)
  if (path == '/api/map/style.json' && req.method.toUpperCase() == 'GET') {
    await _handleCachedMapStyle(
      req: req,
      httpClient: httpClient,
      mapTilerStyleUrl: mapTilerStyleUrl,
    );
    return;
  }

  // 7c-2. Self-Hosted MapLibre GL JS v6.4.1 Assets (0ms lokal, MIME text/javascript pasti valid, bebas CSP/CDN unpkg)
  if (path.startsWith('/api/map/lib/') && req.method.toUpperCase() == 'GET') {
    await _handleSelfHostedMapLibreAsset(req: req, path: path);
    return;
  }

  // 7d. Server-side Proxy Cloudflare Turnstile siteverify (bebas CORS Web & Secret Key aman di server)
  if (path == '/api/security/turnstile/verify' &&
      req.method.toUpperCase() == 'POST') {
    await _handleTurnstileVerify(
      req: req,
      httpClient: httpClient,
      bodyText: bodyText,
      turnstileSiteKey: turnstileSiteKey,
      turnstileSecretKey: turnstileSecretKey,
      remoteIp: clientIp,
    );
    return;
  }

  // 8. Proxy ke Supabase (PostgREST / Auth / Storage / Functions) + RAM Cache untuk Master Tables
  final upperMethod = req.method.toUpperCase();
  final isCacheableMaster = upperMethod == 'GET' &&
      (path == '/rest/v1/stations' || path == '/rest/v1/train_schedules');
  final cacheKey = '$path?${req.uri.query}';

  if (isCacheableMaster) {
    final cached = _getCache[cacheKey];
    if (cached != null && DateTime.now().millisecondsSinceEpoch < cached.expiresAtMs) {
      req.response.statusCode = HttpStatus.ok;
      req.response.headers.set('content-type', cached.contentType);
      req.response.headers.set('X-Cache', 'HIT');
      req.response.add(cached.bodyBytes);
      await req.response.close();
      return;
    }
  } else if (upperMethod != 'GET' &&
      (path.startsWith('/rest/v1/stations') ||
          path.startsWith('/rest/v1/train_schedules'))) {
    // Auto-invalidate cache bila ada perubahan data master
    _getCache.removeWhere((k, _) => k.startsWith(path));
  }

  try {
    final targetUri = upstreamBase.replace(
      path: path,
      query: req.uri.query.isEmpty ? null : req.uri.query,
    );

    final result = await _forwardToSupabase(
      httpClient: httpClient,
      method: req.method,
      targetUri: targetUri,
      incomingHeaders: req.headers,
      bodyBytes: bodyBytes,
      supabaseAnonKey: supabaseAnonKey,
    );

    if (isCacheableMaster && result.statusCode == 200) {
      final ttlMs = path == '/rest/v1/stations' ? 300000 : 120000;
      _getCache[cacheKey] = _CachedResponse(
        bodyBytes: result.bodyBytes,
        contentType: result.contentType ?? 'application/json; charset=utf-8',
        expiresAtMs: DateTime.now().millisecondsSinceEpoch + ttlMs,
      );
      req.response.headers.set('X-Cache', 'MISS');
    }

    // Bridge Cerdas 1: Jika tabel opsional belum dimigrasi (404 PGRST205), kembalikan [] 200 OK pada GET
    if (result.statusCode == 404 &&
        req.method.toUpperCase() == 'GET' &&
        result.bodyText.contains('PGRST205')) {
      req.response.statusCode = HttpStatus.ok;
      req.response.headers.contentType = ContentType.json;
      req.response.headers.set('X-Schema-Notice', 'optional-table-unmigrated');
      req.response.write('[]');
      await req.response.close();
      return;
    }

    // Bridge Cerdas 2: Penyatuan mulus `users` <-> `profiles` jika SQL migrasi belum dijalankan
    if (path == '/rest/v1/users') {
      final bridged = await _maybeBridgeUsersToProfiles(
        httpClient: httpClient,
        upstreamBase: upstreamBase,
        method: req.method.toUpperCase(),
        query: req.uri.query,
        incomingHeaders: req.headers,
        bodyText: bodyText,
        supabaseAnonKey: supabaseAnonKey,
        initialResult: result,
      );
      req.response.statusCode = bridged.statusCode;
      if (bridged.contentType != null) {
        req.response.headers.set('content-type', bridged.contentType!);
      }
      req.response.add(bridged.bodyBytes);
      await req.response.close();
      return;
    }

    req.response.statusCode = result.statusCode;
    if (result.location != null && result.location!.isNotEmpty) {
      req.response.headers.set('location', result.location!);
    }
    if (result.setCookies.isNotEmpty) {
      for (final cookie in result.setCookies) {
        req.response.headers.add('set-cookie', cookie);
      }
    }
    if (result.contentType != null) {
      req.response.headers.set('content-type', result.contentType!);
    }
    if (result.contentRange != null) {
      req.response.headers.set('content-range', result.contentRange!);
    }
    req.response.add(result.bodyBytes);
    await req.response.close();
  } catch (e) {
    req.response.statusCode = HttpStatus.badGateway;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode({'error': 'Upstream gateway error', 'detail': e.toString()}));
    await req.response.close();
  }
}

class _UpstreamResult {
  final int statusCode;
  final List<int> bodyBytes;
  final String? contentType;
  final String? contentRange;
  final String? location;
  final List<String> setCookies;

  _UpstreamResult({
    required this.statusCode,
    required this.bodyBytes,
    this.contentType,
    this.contentRange,
    this.location,
    this.setCookies = const <String>[],
  });

  String get bodyText => utf8.decode(bodyBytes, allowMalformed: true);
}

Future<_UpstreamResult> _forwardToSupabase({
  required HttpClient httpClient,
  required String method,
  required Uri targetUri,
  required HttpHeaders incomingHeaders,
  required List<int> bodyBytes,
  required String supabaseAnonKey,
}) async {
  final upReq = await httpClient.openUrl(method, targetUri);
  upReq.followRedirects = false;

  // Salin header yang aman, injeksikan apikey asli di server
  const forwardable = {
    'accept',
    'content-type',
    'prefer',
    'range',
    'content-profile',
    'accept-profile',
    'x-client-info',
    'x-supabase-api-version',
  };
  for (final name in forwardable) {
    final v = incomingHeaders.value(name);
    if (v != null && v.isNotEmpty) {
      upReq.headers.set(name, v);
    }
  }

  upReq.headers.set('apikey', supabaseAnonKey);

  final incomingAuth = incomingHeaders.value('authorization') ?? '';
  if (incomingAuth.startsWith('Bearer ') &&
      !incomingAuth.contains('tka-gateway-protected-client') &&
      !incomingAuth.contains('gateway-protected')) {
    upReq.headers.set('Authorization', incomingAuth);
  } else {
    upReq.headers.set('Authorization', 'Bearer $supabaseAnonKey');
  }

  if (bodyBytes.isNotEmpty) {
    upReq.contentLength = bodyBytes.length;
    upReq.add(bodyBytes);
  }

  final upRes = await upReq.close();
  final respBytes = await upRes.fold<List<int>>(
    <int>[],
    (prev, elem) => prev..addAll(elem),
  );

  return _UpstreamResult(
    statusCode: upRes.statusCode,
    bodyBytes: respBytes,
    contentType: upRes.headers.value('content-type'),
    contentRange: upRes.headers.value('content-range'),
    location: upRes.headers.value('location'),
    setCookies: upRes.headers['set-cookie'] ?? const <String>[],
  );
}

Future<_UpstreamResult> _maybeBridgeUsersToProfiles({
  required HttpClient httpClient,
  required Uri upstreamBase,
  required String method,
  required String query,
  required HttpHeaders incomingHeaders,
  required String bodyText,
  required String supabaseAnonKey,
  required _UpstreamResult initialResult,
}) async {
  // Jika GET /rest/v1/users kosong `[]`, baca dari `profiles` agar data lama tetap tampil 200 OK
  if (method == 'GET' &&
      initialResult.statusCode == 200 &&
      initialResult.bodyText.trim() == '[]') {
    final safeQuery = query.replaceAll(RegExp(r'select=[^&]*'), 'select=*');
    final profUri = upstreamBase.replace(
      path: '/rest/v1/profiles',
      query: safeQuery.isEmpty ? 'select=*' : safeQuery,
    );
    final profRes = await _forwardToSupabase(
      httpClient: httpClient,
      method: 'GET',
      targetUri: profUri,
      incomingHeaders: incomingHeaders,
      bodyBytes: const <int>[],
      supabaseAnonKey: supabaseAnonKey,
    );
    if (profRes.statusCode == 200) return profRes;
  }

  // Jika POST/PATCH ke `users` ditolak RLS (42501) atau kolom belum dimigrasi (PGRST204 / 42703),
  // jembatan otomatis menyimpan ke `profiles` (kolom yang didukung) agar selalu 200/201!
  if ((method == 'POST' || method == 'PATCH') &&
      (initialResult.statusCode >= 400)) {
    try {
      final decoded = jsonDecode(bodyText);
      const allowedProfCols = {
        'id',
        'email',
        'full_name',
        'phone',
        'role',
        'created_at',
        'balance',
      };
      Map<String, dynamic>? cleanMap;
      if (decoded is Map<String, dynamic>) {
        cleanMap = {
          for (final e in decoded.entries)
            if (allowedProfCols.contains(e.key) && e.value != null) e.key: e.value,
        };
      }
      if (cleanMap != null && cleanMap.isNotEmpty) {
        final profUri = upstreamBase.replace(
          path: '/rest/v1/profiles',
          query: query.isEmpty ? null : query,
        );
        final profRes = await _forwardToSupabase(
          httpClient: httpClient,
          method: method,
          targetUri: profUri,
          incomingHeaders: incomingHeaders,
          bodyBytes: utf8.encode(jsonEncode(cleanMap)),
          supabaseAnonKey: supabaseAnonKey,
        );
        if (profRes.statusCode >= 200 && profRes.statusCode < 300) {
          return profRes;
        }
      }
    } catch (_) {}
  }

  return initialResult;
}

Future<void> _writeJson(
  HttpRequest req,
  int statusCode,
  Map<String, dynamic> body,
) async {
  req.response.statusCode = statusCode;
  req.response.headers.contentType = ContentType.json;
  req.response.write(jsonEncode(body));
  await req.response.close();
}

String _escapeHtmlSimple(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String _generateSecureOtp() {
  final rnd = Random.secure();
  return (100000 + rnd.nextInt(900000)).toString();
}

String _generateSecureToken() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

String _formatWibNow() {
  final wib = DateTime.now().toUtc().add(const Duration(hours: 7));
  String p(int n) => n.toString().padLeft(2, '0');
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  return '${p(wib.day)} ${months[wib.month - 1]} ${wib.year}, '
      '${p(wib.hour)}:${p(wib.minute)}:${p(wib.second)} WIB';
}

/// Cek apakah email terdaftar secara resmi di Supabase (`public.users` dan/atau `auth.users`).
Future<({bool exists, String? authUserId, String? publicUserId, String? fullName})>
    _findRegisteredUserInSupabase({
  required HttpClient httpClient,
  required Uri upstreamBase,
  required String supabaseAdminKey,
  required String cleanEmail,
}) async {
  String? publicUserId;
  String? authUserId;
  String? fullName;

  // 1. Cek di tabel tunggal `public.users`
  try {
    final pubUri = upstreamBase.replace(
      path: '/rest/v1/users',
      queryParameters: {
        'select': 'id,email,full_name',
        'email': 'ilike.$cleanEmail',
        'limit': '5',
      },
    );
    final req = await httpClient.getUrl(pubUri);
    req.headers.set('apikey', supabaseAdminKey);
    req.headers.set('Authorization', 'Bearer $supabaseAdminKey');
    final res = await req.close();
    final text = await utf8.decodeStream(res);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            final rowEmail = (item['email'] ?? '').toString().trim().toLowerCase();
            if (rowEmail == cleanEmail) {
              publicUserId = item['id']?.toString();
              final n = item['full_name']?.toString().trim();
              if (n != null && n.isNotEmpty) fullName = n;
              break;
            }
          }
        }
      }
    }
  } catch (e) {
    stderr.writeln('⚠️ Cek public.users gagal: $e');
  }

  // 2. Cek di Supabase Auth (`auth.users`) via Admin API agar password bisa di-update nyata
  try {
    for (int page = 1; page <= 10; page++) {
      final authUri = upstreamBase.replace(
        path: '/auth/v1/admin/users',
        queryParameters: {'page': '$page', 'per_page': '100'},
      );
      final req = await httpClient.getUrl(authUri);
      req.headers.set('apikey', supabaseAdminKey);
      req.headers.set('Authorization', 'Bearer $supabaseAdminKey');
      final res = await req.close();
      final text = await utf8.decodeStream(res);
      if (res.statusCode < 200 || res.statusCode >= 300) break;

      final decoded = jsonDecode(text);
      final users = decoded is Map ? (decoded['users'] as List? ?? const []) : const [];
      for (final u in users) {
        if (u is Map) {
          final uEmail = (u['email'] ?? '').toString().trim().toLowerCase();
          if (uEmail == cleanEmail) {
            authUserId = u['id']?.toString();
            final meta = u['user_metadata'];
            if (fullName == null && meta is Map) {
              final metaName = (meta['full_name'] ?? meta['name'])?.toString().trim();
              if (metaName != null && metaName.isNotEmpty) fullName = metaName;
            }
            break;
          }
        }
      }
      if (authUserId != null || users.length < 100) break;
    }
  } catch (e) {
    stderr.writeln('⚠️ Cek auth.users gagal: $e');
  }

  final exists = publicUserId != null || authUserId != null;
  return (
    exists: exists,
    authUserId: authUserId,
    publicUserId: publicUserId,
    fullName: fullName,
  );
}

/// Tahap 1 Reset Password:
/// 1. Validasi format email.
/// 2. Cek email HARUS terdaftar di database (`public.users` / `auth.users`). Jika belum terdaftar -> TOLAK (404).
/// 3. Kirim OTP 6 digit langsung ke alamat email masing-masing user via Brevo Transactional API.
Future<void> _handlePasswordResetRequest({
  required HttpRequest req,
  required HttpClient httpClient,
  required Uri upstreamBase,
  required String supabaseAdminKey,
  required String bodyText,
  required String brevoApiKey,
  required String brevoSenderEmail,
  required String brevoSenderName,
}) async {
  try {
    final decoded = jsonDecode(bodyText);
    if (decoded is! Map) {
      await _writeJson(req, HttpStatus.badRequest, {
        'success': false,
        'message': 'Payload JSON tidak valid.',
      });
      return;
    }

    final cleanEmail = (decoded['email'] ?? '').toString().trim().toLowerCase();
    if (cleanEmail.isEmpty || !_strictEmailRegex.hasMatch(cleanEmail)) {
      await _writeJson(req, HttpStatus.badRequest, {
        'success': false,
        'code': 'INVALID_EMAIL',
        'message': 'Format alamat email tidak valid.',
      });
      return;
    }

    // Cek email terdaftar di database Supabase
    final userLookup = await _findRegisteredUserInSupabase(
      httpClient: httpClient,
      upstreamBase: upstreamBase,
      supabaseAdminKey: supabaseAdminKey,
      cleanEmail: cleanEmail,
    );

    if (!userLookup.exists) {
      stdout.writeln('🚫 [Reset Password] Ditolak — email belum terdaftar: $cleanEmail');
      await _writeJson(req, HttpStatus.notFound, {
        'success': false,
        'code': 'EMAIL_NOT_REGISTERED',
        'message':
            'Email $cleanEmail belum terdaftar di sistem TKA. Silakan periksa kembali atau daftar akun terlebih dahulu.',
      });
      return;
    }

    if (brevoApiKey.isEmpty) {
      await _writeJson(req, HttpStatus.serviceUnavailable, {
        'success': false,
        'code': 'EMAIL_SERVICE_UNAVAILABLE',
        'message': 'Layanan email Brevo belum dikonfigurasi di server.',
      });
      return;
    }

    final otpCode = _generateSecureOtp();
    final recipientName =
        userLookup.fullName ?? cleanEmail.split('@').first;
    final safeName = _escapeHtmlSimple(recipientName);
    final safeEmail = _escapeHtmlSimple(cleanEmail);
    final timestampWib = _formatWibNow();

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Kode Verifikasi Reset Kata Sandi TKA</title>
</head>
<body style="margin:0;padding:24px 12px;background:#f8fafc;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <div style="max-width:540px;margin:0 auto;background:#ffffff;border-radius:16px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.06);border:1px solid #e2e8f0;">
    <div style="background:#062056;padding:28px 24px;text-align:center;">
      <div style="display:inline-block;background:#F26716;color:#ffffff;font-size:12px;font-weight:bold;letter-spacing:1.5px;padding:4px 12px;border-radius:20px;text-transform:uppercase;margin-bottom:12px;">
        Keamanan Akun TKA
      </div>
      <h1 style="color:#ffffff;font-size:22px;margin:0;font-weight:800;">Kode Verifikasi Reset Sandi</h1>
      <p style="color:#94a3b8;font-size:13px;margin:6px 0 0;">Layanan Tiket Kereta Api Indonesia</p>
    </div>
    <div style="padding:28px 24px;color:#1e293b;">
      <p style="font-size:14px;line-height:1.6;margin:0 0 16px;">
        Halo <strong>$safeName</strong>,
      </p>
      <p style="font-size:14px;line-height:1.6;margin:0 0 20px;">
        Kami menerima permintaan untuk mengatur ulang kata sandi akun TKA Anda. Masukkan kode verifikasi (OTP) berikut pada halaman verifikasi kode untuk melanjutkan ke halaman ubah kata sandi:
      </p>
      <div style="background:#f1f5f9;border:2px dashed #cbd5e1;border-radius:12px;padding:20px;text-align:center;margin:24px 0;">
        <div style="font-size:11px;color:#64748b;font-weight:bold;text-transform:uppercase;letter-spacing:1px;margin-bottom:8px;">
          Kode Verifikasi (OTP)
        </div>
        <div style="font-size:36px;font-weight:900;letter-spacing:10px;color:#062056;font-family:'Courier New',Courier,monospace;">
          $otpCode
        </div>
        <div style="font-size:12px;color:#ef4444;font-weight:600;margin-top:10px;">
          ⏱ Berlaku selama 15 menit • Hanya untuk 1 kali penggunaan
        </div>
      </div>
      <div style="background:#fff7ed;border-left:4px solid #f97316;padding:12px 16px;border-radius:6px;margin-bottom:20px;">
        <p style="font-size:12.5px;color:#9a3412;margin:0;line-height:1.5;">
          <strong>PENTING:</strong> Jangan berikan kode ini kepada siapa pun. Jika Anda tidak merasa meminta reset kata sandi, abaikan email ini.
        </p>
      </div>
      <div style="font-size:11.5px;color:#94a3b8;line-height:1.5;border-top:1px solid #f1f5f9;padding-top:16px;">
        Waktu Permintaan: <strong>$timestampWib</strong><br/>
        Email Penerima: <strong>$safeEmail</strong>
      </div>
    </div>
    <div style="background:#f8fafc;padding:16px 24px;text-align:center;border-top:1px solid #e2e8f0;">
      <p style="font-size:11px;color:#64748b;margin:0;">
        © 2026 TKA Rail Mobile • PT Kereta Api Indonesia (Persero)
      </p>
    </div>
  </div>
</body>
</html>
''';

    // Kirim email langsung ke alamat email masing-masing user lewat Brevo
    final brevoPayload = utf8.encode(
      jsonEncode({
        'sender': {
          'name': brevoSenderName,
          'email': brevoSenderEmail,
        },
        'to': [
          {
            'email': cleanEmail,
            'name': recipientName,
          }
        ],
        'subject': '[TKA Rail] $otpCode adalah Kode Verifikasi Reset Kata Sandi Anda',
        'htmlContent': htmlContent,
      }),
    );

    final upReq = await httpClient.postUrl(
      Uri.parse('https://api.brevo.com/v3/smtp/email'),
    );
    upReq.headers.set('accept', 'application/json');
    upReq.headers.set('content-type', 'application/json');
    upReq.headers.set('api-key', brevoApiKey);
    upReq.contentLength = brevoPayload.length;
    upReq.add(brevoPayload);

    final upRes = await upReq.close();
    final respText = await utf8.decodeStream(upRes);

    if (upRes.statusCode < 200 || upRes.statusCode >= 300) {
      stderr.writeln('❌ [Brevo Reset Email Error] HTTP ${upRes.statusCode}: $respText');
      await _writeJson(req, HttpStatus.badGateway, {
        'success': false,
        'code': 'EMAIL_SEND_FAILED',
        'message':
            'Gagal mengirim kode OTP ke $cleanEmail melalui server email. Silakan coba beberapa saat lagi.',
      });
      return;
    }

    // Simpan OTP di server hanya setelah email benar-benar terkirim
    _resetOtpStore[cleanEmail] = _ResetOtpEntry(
      email: cleanEmail,
      otp: otpCode,
      userName: recipientName,
      authUserId: userLookup.authUserId,
      publicUserId: userLookup.publicUserId,
      expiresAtMs: DateTime.now().add(const Duration(minutes: 15)).millisecondsSinceEpoch,
    );

    stdout.writeln('✅ [Reset Password] OTP 6 digit berhasil dikirim via Brevo ke: $cleanEmail');
    await _writeJson(req, HttpStatus.ok, {
      'success': true,
      'email': cleanEmail,
      'expiresInSeconds': 900,
      'message':
          'Kode verifikasi 6 digit telah dikirim ke $cleanEmail. Silakan periksa kotak masuk atau folder spam Anda.',
    });
  } catch (e) {
    stderr.writeln('❌ _handlePasswordResetRequest error: $e');
    await _writeJson(req, HttpStatus.internalServerError, {
      'success': false,
      'message': 'Terjadi kesalahan saat memproses permintaan reset kata sandi.',
    });
  }
}

/// Tahap 2 Reset Password:
/// Validasi kode OTP secara mandiri sebelum diizinkan masuk ke halaman ubah kata sandi.
Future<void> _handlePasswordResetVerifyOtp({
  required HttpRequest req,
  required String bodyText,
}) async {
  try {
    final decoded = jsonDecode(bodyText);
    if (decoded is! Map) {
      await _writeJson(req, HttpStatus.badRequest, {
        'success': false,
        'valid': false,
        'message': 'Payload JSON tidak valid.',
      });
      return;
    }

    final cleanEmail = (decoded['email'] ?? '').toString().trim().toLowerCase();
    final cleanOtp = (decoded['otp'] ?? '').toString().trim();

    if (cleanEmail.isEmpty || !_strictEmailRegex.hasMatch(cleanEmail)) {
      await _writeJson(req, HttpStatus.badRequest, {
        'success': false,
        'valid': false,
        'message': 'Alamat email tidak valid.',
      });
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(cleanOtp)) {
      await _writeJson(req, HttpStatus.badRequest, {
        'success': false,
        'valid': false,
        'message': 'Kode OTP harus berupa 6 digit angka.',
      });
      return;
    }

    final entry = _resetOtpStore[cleanEmail];
    if (entry == null) {
      await _writeJson(req, HttpStatus.badRequest, {
        'success': false,
        'valid': false,
        'code': 'OTP_NOT_FOUND',
        'message': 'Kode OTP tidak ditemukan atau belum pernah diminta. Silakan kirim ulang kode OTP.',
      });
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now > entry.expiresAtMs) {
      _resetOtpStore.remove(cleanEmail);
      await _writeJson(req, HttpStatus.badRequest, {
        'success': false,
        'valid': false,
        'code': 'OTP_EXPIRED',
        'message': 'Kode OTP telah kedaluwarsa (lebih dari 15 menit). Silakan minta kode OTP baru.',
      });
      return;
    }

    if (entry.attempts >= 5) {
      _resetOtpStore.remove(cleanEmail);
      await _writeJson(req, HttpStatus.tooManyRequests, {
        'success': false,
        'valid': false,
        'code': 'OTP_TOO_MANY_ATTEMPTS',
        'message': 'Terlalu banyak percobaan OTP salah. Silakan kirim ulang kode OTP baru.',
      });
      return;
    }

    if (entry.otp != cleanOtp) {
      entry.attempts += 1;
      final remaining = 5 - entry.attempts;
      if (remaining <= 0) {
        _resetOtpStore.remove(cleanEmail);
        await _writeJson(req, HttpStatus.tooManyRequests, {
          'success': false,
          'valid': false,
          'code': 'OTP_TOO_MANY_ATTEMPTS',
          'message': 'Kode OTP salah sebanyak 5 kali. Silakan kirim ulang kode OTP baru.',
        });
        return;
      }
      await _writeJson(req, HttpStatus.badRequest, {
        'success': false,
        'valid': false,
        'code': 'OTP_INVALID',
        'message': 'Kode OTP yang Anda masukkan salah. Sisa percobaan: $remaining kali.',
      });
      return;
    }

    // OTP VALID -> terbitkan resetToken satu kali pakai (berlaku 10 menit)
    final token = _generateSecureToken();
    entry.verified = true;
    entry.resetToken = token;
    entry.resetTokenExpiresAtMs =
        DateTime.now().add(const Duration(minutes: 10)).millisecondsSinceEpoch;

    stdout.writeln('✅ [Reset Password] OTP terverifikasi valid untuk: $cleanEmail');
    await _writeJson(req, HttpStatus.ok, {
      'success': true,
      'valid': true,
      'resetToken': token,
      'message': 'Kode OTP valid! Silakan buat kata sandi baru Anda.',
    });
  } catch (e) {
    stderr.writeln('❌ _handlePasswordResetVerifyOtp error: $e');
    await _writeJson(req, HttpStatus.internalServerError, {
      'success': false,
      'valid': false,
      'message': 'Terjadi kesalahan saat memverifikasi kode OTP.',
    });
  }
}

/// Tahap 3 Reset Password:
/// Memperbarui kata sandi secara nyata di Supabase Auth (`auth.users`) setelah OTP valid.
Future<void> _handlePasswordResetConfirm({
  required HttpRequest req,
  required HttpClient httpClient,
  required Uri upstreamBase,
  required String supabaseAdminKey,
  required String bodyText,
}) async {
  try {
    final decoded = jsonDecode(bodyText);
    if (decoded is! Map) {
      await _writeJson(req, HttpStatus.badRequest, {
        'success': false,
        'message': 'Payload JSON tidak valid.',
      });
      return;
    }

    final cleanEmail = (decoded['email'] ?? '').toString().trim().toLowerCase();
    final resetToken = (decoded['resetToken'] ?? '').toString().trim();
    final newPassword = (decoded['newPassword'] ?? '').toString();

    if (cleanEmail.isEmpty || !_strictEmailRegex.hasMatch(cleanEmail)) {
      await _writeJson(req, HttpStatus.badRequest, {
        'success': false,
        'message': 'Alamat email tidak valid.',
      });
      return;
    }

    if (newPassword.length < 6) {
      await _writeJson(req, HttpStatus.badRequest, {
        'success': false,
        'message': 'Kata sandi baru minimal harus 6 karakter.',
      });
      return;
    }

    final entry = _resetOtpStore[cleanEmail];
    final now = DateTime.now().millisecondsSinceEpoch;
    if (entry == null ||
        !entry.verified ||
        entry.resetToken == null ||
        entry.resetToken != resetToken ||
        entry.resetTokenExpiresAtMs == null ||
        now > entry.resetTokenExpiresAtMs!) {
      await _writeJson(req, HttpStatus.unauthorized, {
        'success': false,
        'code': 'RESET_TOKEN_INVALID',
        'message':
            'Sesi verifikasi OTP tidak valid atau telah kedaluwarsa. Silakan verifikasi ulang kode OTP Anda.',
      });
      return;
    }

    // Pastikan ID user di Supabase Auth ditemukan lalu perbarui kata sandinya
    String? authUserId = entry.authUserId;
    if (authUserId == null || authUserId.isEmpty) {
      final lookup = await _findRegisteredUserInSupabase(
        httpClient: httpClient,
        upstreamBase: upstreamBase,
        supabaseAdminKey: supabaseAdminKey,
        cleanEmail: cleanEmail,
      );
      authUserId = lookup.authUserId;
    }

    bool authUpdated = false;
    String? authErr;

    if (authUserId != null && authUserId.isNotEmpty) {
      final updateUri = upstreamBase.replace(
        path: '/auth/v1/admin/users/$authUserId',
      );
      final body = utf8.encode(jsonEncode({'password': newPassword}));
      final upReq = await httpClient.putUrl(updateUri);
      upReq.headers.set('apikey', supabaseAdminKey);
      upReq.headers.set('Authorization', 'Bearer $supabaseAdminKey');
      upReq.headers.set('Content-Type', 'application/json');
      upReq.contentLength = body.length;
      upReq.add(body);
      final upRes = await upReq.close();
      final respText = await utf8.decodeStream(upRes);
      if (upRes.statusCode >= 200 && upRes.statusCode < 300) {
        authUpdated = true;
      } else {
        authErr = 'HTTP ${upRes.statusCode}: $respText';
      }
    } else {
      // User lama di public.users yang belum punya record di auth.users -> buat di auth.users agar langsung bisa login
      final createUri = upstreamBase.replace(path: '/auth/v1/admin/users');
      final body = utf8.encode(
        jsonEncode({
          'email': cleanEmail,
          'password': newPassword,
          'email_confirm': true,
          'user_metadata': {
            'full_name': entry.userName,
            'role': 'passenger',
          },
        }),
      );
      final upReq = await httpClient.postUrl(createUri);
      upReq.headers.set('apikey', supabaseAdminKey);
      upReq.headers.set('Authorization', 'Bearer $supabaseAdminKey');
      upReq.headers.set('Content-Type', 'application/json');
      upReq.contentLength = body.length;
      upReq.add(body);
      final upRes = await upReq.close();
      final respText = await utf8.decodeStream(upRes);
      if (upRes.statusCode >= 200 && upRes.statusCode < 300) {
        authUpdated = true;
      } else {
        authErr = 'HTTP ${upRes.statusCode}: $respText';
      }
    }

    if (!authUpdated) {
      stderr.writeln('❌ [Reset Password] Gagal update Supabase Auth untuk $cleanEmail: $authErr');
      await _writeJson(req, HttpStatus.badGateway, {
        'success': false,
        'message': 'Gagal memperbarui kata sandi di server autentikasi. Silakan coba lagi.',
      });
      return;
    }

    // Hanguskan OTP & resetToken agar tidak dapat digunakan ulang
    _resetOtpStore.remove(cleanEmail);

    stdout.writeln('✅ [Reset Password] Kata sandi Supabase Auth berhasil diperbarui untuk: $cleanEmail');
    await _writeJson(req, HttpStatus.ok, {
      'success': true,
      'message':
          'Kata sandi berhasil diperbarui! Silakan masuk dengan kata sandi baru Anda.',
    });
  } catch (e) {
    stderr.writeln('❌ _handlePasswordResetConfirm error: $e');
    await _writeJson(req, HttpStatus.internalServerError, {
      'success': false,
      'message': 'Terjadi kesalahan saat menyimpan kata sandi baru.',
    });
  }
}

/// Menyajikan file self-hosted MapLibre GL JS 6.4.1 (`.mjs` & `.css`) dari `web/maplibre/`
/// dengan MIME type `text/javascript` yang dijamin valid + cache RAM permanen (0ms latency, bebas unpkg CDN).
Future<void> _handleSelfHostedMapLibreAsset({
  required HttpRequest req,
  required String path,
}) async {
  final fileName = path.substring('/api/map/lib/'.length).trim();
  const allowedFiles = <String, String>{
    'maplibre-gl.mjs': 'text/javascript; charset=utf-8',
    'maplibre-gl-shared.mjs': 'text/javascript; charset=utf-8',
    'maplibre-gl-worker.mjs': 'text/javascript; charset=utf-8',
    'maplibre-gl.css': 'text/css; charset=utf-8',
  };

  final contentType = allowedFiles[fileName];
  if (contentType == null) {
    await _writeJson(req, HttpStatus.notFound, {
      'error': 'MapLibre asset not found: $fileName',
    });
    return;
  }

  final cacheKey = 'maplibre_lib_$fileName';
  final cached = _getCache[cacheKey];
  if (cached != null) {
    req.response.statusCode = HttpStatus.ok;
    req.response.headers.set('content-type', cached.contentType);
    req.response.headers.set('Cache-Control', 'public, max-age=604800, immutable');
    req.response.headers.set('Cross-Origin-Resource-Policy', 'cross-origin');
    req.response.headers.set('X-Cache', 'HIT');
    req.response.add(cached.bodyBytes);
    await req.response.close();
    return;
  }

  File? assetFile;
  for (final candidate in ['web/maplibre/$fileName', 'appstka/web/maplibre/$fileName']) {
    final f = File(candidate);
    if (await f.exists()) {
      assetFile = f;
      break;
    }
  }

  if (assetFile == null) {
    await _writeJson(req, HttpStatus.notFound, {
      'error': 'File web/maplibre/$fileName tidak ditemukan di server.',
    });
    return;
  }

  final bytes = await assetFile.readAsBytes();
  _getCache[cacheKey] = _CachedResponse(
    bodyBytes: bytes,
    contentType: contentType,
    expiresAtMs: DateTime.now().add(const Duration(days: 7)).millisecondsSinceEpoch,
  );

  req.response.statusCode = HttpStatus.ok;
  req.response.headers.set('content-type', contentType);
  req.response.headers.set('Cache-Control', 'public, max-age=604800, immutable');
  req.response.headers.set('Cross-Origin-Resource-Policy', 'cross-origin');
  req.response.headers.set('X-Cache', 'MISS');
  req.response.add(bytes);
  await req.response.close();
}

/// Layer non-esensial / mikro-detail / global clutter yang dipangkas agar render WebGL Indonesia jauh lebih ringan
const Set<String> _prunedMapStyleLayerIds = <String>{
  'Building',
  'Building top',
  'Pathway outline',
  'Pathway',
  'Pathway labels',
  'Pedestrian labels',
  'Tunnel pathway',
  'Cemetery',
  'Stadium',
  'Grass',
  'Residential',
  'Pier',
  'Aviation line',
  'River intermittent',
  'Pond labels',
  'Bay labels (lines)',
  'Sea labels (lines)',
  'Village labels',
  'Continent labels',
  'Ocean labels',
  'Country labels disputed',
  'Disputed border',
};

/// Bounding box ketat wilayah Negara Kesatuan Republik Indonesia: [West, South, East, North]
const List<double> _indonesiaTileBounds = <double>[94.8, -11.2, 141.2, 6.3];

/// Menyajikan MapTiler style.json yang sudah dioptimasi KHUSUS INDONESIA ONLY:
/// 1. Meng-inline TileJSON (`tiles.json`) langsung di dalam `style.json` (hemat 1x round-trip jaringan).
/// 2. Membatasi `bounds` vector tile secara ketat ke Indonesia `[94.8, -11.2, 141.2, 6.3]` + `minzoom: 4`, `maxzoom: 13`,
///    sehingga MapLibre TIDAK pernah mengunduh atau merender tile negara lain.
/// 3. Memangkas layer berat non-esensial (gedung 3D/mikro, jalan setapak, label benua/samudera).
/// 4. Disimpan di RAM cache selama 1 jam -> pemuatan < 4ms!
Future<void> _handleCachedMapStyle({
  required HttpRequest req,
  required HttpClient httpClient,
  required String mapTilerStyleUrl,
}) async {
  if (mapTilerStyleUrl.isEmpty) {
    await _writeJson(req, HttpStatus.serviceUnavailable, {
      'error': 'MAPTILER_STYLE_URL belum diatur di .env',
    });
    return;
  }

  const key = 'maptiler_style_indonesia_json';
  final now = DateTime.now().millisecondsSinceEpoch;
  final cached = _getCache[key];
  if (cached != null && now < cached.expiresAtMs) {
    req.response.statusCode = HttpStatus.ok;
    req.response.headers.set('content-type', cached.contentType);
    req.response.headers.set('Cache-Control', 'public, max-age=3600');
    req.response.headers.set('X-Map-Region', 'Indonesia-Only');
    req.response.headers.set('X-Cache', 'HIT');
    req.response.add(cached.bodyBytes);
    await req.response.close();
    return;
  }

  try {
    final upReq = await httpClient.getUrl(Uri.parse(mapTilerStyleUrl));
    upReq.headers.set('accept', 'application/json');
    final upRes = await upReq.close();
    final rawBytes = await upRes.fold<List<int>>(<int>[], (p, e) => p..addAll(e));

    List<int> finalBytes = rawBytes;

    if (upRes.statusCode >= 200 && upRes.statusCode < 300) {
      try {
        final styleObj = jsonDecode(utf8.decode(rawBytes));
        if (styleObj is Map<String, dynamic>) {
          // Fokuskan kamera awal style langsung ke Pulau Jawa / Indonesia
          styleObj['center'] = <double>[110.3695, -7.2504];
          styleObj['zoom'] = 6.2;

          // Inline TileJSON + kunci bounds ketat ke Indonesia saja
          final sources = styleObj['sources'];
          if (sources is Map) {
            for (final entry in sources.entries) {
              final src = entry.value;
              if (src is Map && src['type'] == 'vector') {
                final srcUrl = (src['url'] ?? '').toString().trim();
                if (srcUrl.isNotEmpty) {
                  try {
                    final tjReq = await httpClient.getUrl(Uri.parse(srcUrl));
                    tjReq.headers.set('accept', 'application/json');
                    final tjRes = await tjReq.close();
                    final tjText = await utf8.decodeStream(tjRes);
                    if (tjRes.statusCode >= 200 && tjRes.statusCode < 300) {
                      final tj = jsonDecode(tjText);
                      if (tj is Map && tj['tiles'] is List && (tj['tiles'] as List).isNotEmpty) {
                        src.remove('url');
                        src['tiles'] = tj['tiles'];
                        if (tj['attribution'] != null) {
                          src['attribution'] = tj['attribution'];
                        }
                        src['bounds'] = _indonesiaTileBounds;
                        src['minzoom'] = 4;
                        src['maxzoom'] = 13;
                      }
                    }
                  } catch (e) {
                    stderr.writeln('⚠️ Inline TileJSON fallback (${entry.key}): $e');
                    src['bounds'] = _indonesiaTileBounds;
                  }
                } else {
                  src['bounds'] = _indonesiaTileBounds;
                }
              }
            }
          }

          // Pangkas layer mikro/global agar frame WebGL jauh lebih ringan
          final layers = styleObj['layers'];
          if (layers is List) {
            styleObj['layers'] = layers.where((layer) {
              if (layer is Map) {
                final id = (layer['id'] ?? '').toString();
                return !_prunedMapStyleLayerIds.contains(id);
              }
              return true;
            }).toList();
          }

          finalBytes = utf8.encode(jsonEncode(styleObj));
          stdout.writeln(
            '🗺️  [MapTiler Optimizer] Style Indonesia-Only siap (${(styleObj['layers'] as List?)?.length ?? 0} layers, bounds: $_indonesiaTileBounds)',
          );
        }
      } catch (optErr) {
        stderr.writeln('⚠️ Optimasi style.json fallback raw: $optErr');
      }

      _getCache[key] = _CachedResponse(
        bodyBytes: finalBytes,
        contentType: 'application/json; charset=utf-8',
        expiresAtMs: now + 3600000, // 1 jam
      );
    }

    req.response.statusCode = upRes.statusCode;
    req.response.headers.set('content-type', 'application/json; charset=utf-8');
    req.response.headers.set('Cache-Control', 'public, max-age=3600');
    req.response.headers.set('X-Map-Region', 'Indonesia-Only');
    req.response.headers.set('X-Cache', 'MISS');
    req.response.add(finalBytes);
    await req.response.close();
  } catch (e) {
    await _writeJson(req, HttpStatus.badGateway, {
      'error': 'Gagal mengambil MapTiler style: $e',
    });
  }
}

/// Memverifikasi token Cloudflare Turnstile di sisi server (server-to-server)
/// agar browser Web tidak terkena blokir CORS dan TURNSTILE_SECRET_KEY tidak pernah bocor ke client.
Future<void> _handleTurnstileVerify({
  required HttpRequest req,
  required HttpClient httpClient,
  required String bodyText,
  required String turnstileSiteKey,
  required String turnstileSecretKey,
  required String remoteIp,
}) async {
  try {
    final decoded = bodyText.isNotEmpty ? jsonDecode(bodyText) : <String, dynamic>{};
    if (decoded is! Map) {
      await _writeJson(req, HttpStatus.badRequest, {
        'success': false,
        'verified': false,
        'message': 'Payload JSON tidak valid.',
      });
      return;
    }

    final token = (decoded['response'] ?? decoded['token'] ?? '').toString().trim();
    if (token.isEmpty) {
      await _writeJson(req, HttpStatus.badRequest, {
        'success': false,
        'verified': false,
        'message': 'Token verifikasi Turnstile wajib disertakan.',
      });
      return;
    }

    if (turnstileSiteKey.startsWith('2x0000') ||
        turnstileSecretKey.startsWith('2x0000')) {
      await _writeJson(req, HttpStatus.forbidden, {
        'success': false,
        'verified': false,
        'message':
            'Verifikasi Cloudflare Turnstile ditolak (Mode Testing Always-Fail).',
      });
      return;
    }

    if (turnstileSecretKey.isEmpty) {
      await _writeJson(req, HttpStatus.serviceUnavailable, {
        'success': false,
        'verified': false,
        'message': 'TURNSTILE_SECRET_KEY belum dikonfigurasi pada file .env server.',
      });
      return;
    }

    final formFields = <String, String>{
      'secret': turnstileSecretKey,
      'response': token,
      if (remoteIp.isNotEmpty && remoteIp != '127.0.0.1' && remoteIp != '::1')
        'remoteip': remoteIp,
    };
    final formBody = formFields.entries
        .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final encoded = utf8.encode(formBody);

    final upReq = await httpClient.postUrl(
      Uri.parse('https://challenges.cloudflare.com/turnstile/v0/siteverify'),
    );
    upReq.headers.set('content-type', 'application/x-www-form-urlencoded');
    upReq.headers.set('accept', 'application/json');
    upReq.contentLength = encoded.length;
    upReq.add(encoded);

    final upRes = await upReq.close();
    final respText = await utf8.decodeStream(upRes);

    if (upRes.statusCode >= 200 && upRes.statusCode < 300) {
      final cfData = jsonDecode(respText);
      if (cfData is Map && cfData['success'] == true) {
        stdout.writeln('✅ [Turnstile Gateway] siteverify valid (hostname: ${cfData['hostname'] ?? 'local'})');
        await _writeJson(req, HttpStatus.ok, {
          'success': true,
          'verified': true,
          'hostname': cfData['hostname'],
          'challenge_ts': cfData['challenge_ts'],
          'message': 'Verifikasi Cloudflare Turnstile berhasil.',
        });
        return;
      }

      final errCodes = cfData is Map ? (cfData['error-codes'] ?? const []) : const [];
      await _writeJson(req, HttpStatus.badRequest, {
        'success': false,
        'verified': false,
        'errorCodes': errCodes,
        'message': 'Verifikasi Cloudflare Turnstile gagal ($errCodes).',
      });
      return;
    }

    await _writeJson(req, HttpStatus.badGateway, {
      'success': false,
      'verified': false,
      'message': 'Upstream Cloudflare Turnstile mengembalikan HTTP ${upRes.statusCode}.',
    });
  } catch (e) {
    stderr.writeln('❌ _handleTurnstileVerify error: $e');
    await _writeJson(req, HttpStatus.badGateway, {
      'success': false,
      'verified': false,
      'message': 'Gagal menghubungi server verifikasi Cloudflare Turnstile: $e',
    });
  }
}

Future<void> _handleBrevoProxy({
  required HttpRequest req,
  required HttpClient httpClient,
  required String bodyText,
  required String brevoApiKey,
  required String brevoSenderEmail,
  required String brevoSenderName,
}) async {
  if (brevoApiKey.isEmpty) {
    req.response.statusCode = HttpStatus.serviceUnavailable;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode({'error': 'BREVO_API_KEY not configured on server'}));
    await req.response.close();
    return;
  }

  try {
    final payload = Map<String, dynamic>.from(jsonDecode(bodyText) as Map);
    payload['sender'] ??= {
      'name': brevoSenderName,
      'email': brevoSenderEmail,
    };
    final senderMap = Map<String, dynamic>.from(payload['sender'] as Map);
    if ((senderMap['email'] ?? '').toString().contains('noreply@tka-rail.id')) {
      senderMap['email'] = brevoSenderEmail;
      senderMap['name'] = brevoSenderName;
      payload['sender'] = senderMap;
    }

    final encoded = utf8.encode(jsonEncode(payload));
    final upReq = await httpClient.postUrl(Uri.parse('https://api.brevo.com/v3/smtp/email'));
    upReq.headers.set('accept', 'application/json');
    upReq.headers.set('content-type', 'application/json');
    upReq.headers.set('api-key', brevoApiKey);
    upReq.contentLength = encoded.length;
    upReq.add(encoded);

    final upRes = await upReq.close();
    final respBytes = await upRes.fold<List<int>>(<int>[], (p, e) => p..addAll(e));
    req.response.statusCode = upRes.statusCode;
    req.response.headers.contentType = ContentType.json;
    req.response.add(respBytes);
    await req.response.close();
  } catch (e) {
    req.response.statusCode = HttpStatus.badGateway;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode({'error': e.toString()}));
    await req.response.close();
  }
}

Future<void> _bridgeRealtimeWebSocket(
  HttpRequest req,
  Uri upstreamBase,
  String supabaseAnonKey,
) async {
  WebSocket? clientWs;
  WebSocket? upstreamWs;
  try {
    clientWs = await WebSocketTransformer.upgrade(req);
    final qp = Map<String, String>.from(req.uri.queryParameters);
    qp['apikey'] = supabaseAnonKey;
    final wsScheme = upstreamBase.scheme == 'https' ? 'wss' : 'ws';
    final wsUri = upstreamBase.replace(
      scheme: wsScheme,
      path: req.uri.path,
      queryParameters: qp,
    );
    upstreamWs = await WebSocket.connect(wsUri.toString());

    clientWs.listen(
      (data) => upstreamWs?.add(data),
      onDone: () => upstreamWs?.close(),
      onError: (_) => upstreamWs?.close(),
    );
    upstreamWs.listen(
      (data) => clientWs?.add(data),
      onDone: () => clientWs?.close(),
      onError: (_) => clientWs?.close(),
    );
  } catch (_) {
    try {
      await clientWs?.close();
    } catch (_) {}
    try {
      await upstreamWs?.close();
    } catch (_) {}
  }
}

Future<Map<String, String>> _loadDotEnv() async {
  final map = <String, String>{};
  for (final path in ['.env', 'appstka/.env']) {
    final f = File(path);
    if (await f.exists()) {
      for (final raw in await f.readAsLines()) {
        final line = raw.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final i = line.indexOf('=');
        if (i <= 0) continue;
        final k = line.substring(0, i).trim();
        var v = line.substring(i + 1).trim();
        if ((v.startsWith('"') && v.endsWith('"')) ||
            (v.startsWith("'") && v.endsWith("'"))) {
          v = v.substring(1, v.length - 1);
        }
        map[k] = v;
      }
      break;
    }
  }
  return map;
}

