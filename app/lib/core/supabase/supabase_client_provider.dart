import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_client_provider.g.dart';

/// The initialized Supabase client (`BACKEND=supabase` only).
///
/// Overridden in `bootstrap.dart` after `Supabase.initialize`. Data sources
/// read it; presentation and domain never do.
@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) {
  throw UnimplementedError(
    'supabaseClientProvider is only available with BACKEND=supabase.',
  );
}
