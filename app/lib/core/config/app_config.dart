import 'package:flui/core/error/failure.dart';
import 'package:flui/core/error/result.dart';

enum Backend { fake, supabase }

/// Compile-time configuration from `--dart-define-from-file=config/<env>.json`.
///
/// Keys: `BACKEND` (`fake` | `supabase`, default `supabase`), `SUPABASE_URL`,
/// `SUPABASE_ANON_KEY` and the optional `APP_URL`.
final class AppConfig {
  const new({
    required this.backend,
    this.supabaseUrl,
    this.supabaseAnonKey,
    this.appUrl,
  });

  /// Reads the dart-defines baked into this build.
  static Result<AppConfig> fromEnvironment() => parse(const {
    'BACKEND': String.fromEnvironment('BACKEND'),
    'SUPABASE_URL': String.fromEnvironment('SUPABASE_URL'),
    'SUPABASE_ANON_KEY': String.fromEnvironment('SUPABASE_ANON_KEY'),
    'APP_URL': String.fromEnvironment('APP_URL'),
  });

  /// Parses and validates raw values. Empty values count as missing.
  static Result<AppConfig> parse(Map<String, String> values) {
    String? read(String key) {
      final value = values[key]?.trim();
      return value == null || value.isEmpty ? null : value;
    }

    final rawBackend = read('BACKEND')?.toLowerCase() ?? Backend.supabase.name;
    final backend = Backend.values
        .where((b) => b.name == rawBackend)
        .firstOrNull;
    if (backend == null) {
      return Result.err(
        ConfigFailure(
          'BACKEND must be "fake" or "supabase", got "$rawBackend".',
        ),
      );
    }

    final rawAppUrl = read('APP_URL');
    final appUrl = rawAppUrl == null ? null : _httpUrl(rawAppUrl);
    if (rawAppUrl != null && appUrl == null) {
      return const Result.err(
        ConfigFailure('APP_URL must be an absolute http(s) URL.'),
      );
    }

    if (backend == Backend.fake) {
      return Result.ok(AppConfig(backend: backend, appUrl: appUrl));
    }

    final rawUrl = read('SUPABASE_URL');
    final supabaseUrl = rawUrl == null ? null : _httpUrl(rawUrl);
    if (supabaseUrl == null) {
      return const Result.err(
        ConfigFailure(
          'SUPABASE_URL is missing or not an absolute http(s) URL. '
          'Pass --dart-define-from-file=config/<env>.json.',
        ),
      );
    }
    final anonKey = read('SUPABASE_ANON_KEY');
    if (anonKey == null) {
      return const Result.err(ConfigFailure('SUPABASE_ANON_KEY is missing.'));
    }

    return Result.ok(
      AppConfig(
        backend: backend,
        supabaseUrl: supabaseUrl,
        supabaseAnonKey: anonKey,
        appUrl: appUrl,
      ),
    );
  }

  final Backend backend;
  final Uri? supabaseUrl;
  final String? supabaseAnonKey;
  final Uri? appUrl;

  static Uri? _httpUrl(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri;
  }
}
