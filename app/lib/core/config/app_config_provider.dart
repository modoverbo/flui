import 'package:flui/core/config/app_config.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_config_provider.g.dart';

/// Overridden in `bootstrap.dart` with the parsed dart-defines.
@Riverpod(keepAlive: true)
AppConfig appConfig(Ref ref) {
  throw UnimplementedError('appConfigProvider must be overridden.');
}
