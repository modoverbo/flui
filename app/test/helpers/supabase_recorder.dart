import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A real `SupabaseClient` whose HTTP calls are recorded and answered by
/// `respond`, so data sources can be tested against exact table, column and
/// filter names.
final class SupabaseRecorder {
  new({Object? Function(http.Request request)? respond, this.userId = 'u1'}) {
    client = SupabaseClient(
      'https://test.supabase.co',
      'anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      postgrestOptions: const PostgrestClientOptions(retryEnabled: false),
      httpClient: MockClient((request) async {
        requests.add(request);
        final body = (respond ?? (_) => <Object?>[])(request);
        if (body is http.Response) {
          return http.Response(
            body.body,
            body.statusCode,
            headers: body.headers,
            request: request,
          );
        }
        return http.Response(
          body == null ? '' : jsonEncode(body),
          body == null ? 201 : 200,
          headers: {'content-type': 'application/json; charset=utf-8'},
          request: request,
        );
      }),
    );
  }

  final String? userId;
  final requests = <http.Request>[];
  late final SupabaseClient client;

  http.Request get last => requests.last;

  Object? bodyOf(http.Request request) =>
      request.body.isEmpty ? null : jsonDecode(request.body);

  Future<void> dispose() => client.dispose();
}
