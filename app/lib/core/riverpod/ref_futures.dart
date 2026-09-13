import 'package:riverpod_annotation/riverpod_annotation.dart';

extension RefFutures on Ref {
  /// Awaits [provider] from a notifier method.
  ///
  /// Riverpod pauses providers without listeners (a stream provider would
  /// never emit), so this listens until the value arrives.
  Future<T> readFuture<T>(ProviderListenable<Future<T>> provider) async {
    final subscription = listen(provider, (_, _) {});
    try {
      return await subscription.read();
    } finally {
      subscription.close();
    }
  }
}
