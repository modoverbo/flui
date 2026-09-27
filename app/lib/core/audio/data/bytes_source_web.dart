import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flui/core/audio/data/bytes_source.dart';
import 'package:web/web.dart' as web;

InMemoryAudioSource createInMemoryAudioSource() => WebBlobAudioSource();

/// A `Blob` + `URL.createObjectURL` in-memory source (U3 spike: PASS on
/// Chrome — `AudioSource.uri(blob: URL)` plays an in-memory WAV after a
/// user gesture). [_lifecycle] is the pure create/revoke bookkeeping —
/// the only part of this class a VM-side unit test can exercise, since
/// `dart:js_interop`/`package:web` do not run outside a browser/JS runtime
/// (see `bytes_source_test.dart` for `BlobUrlLifecycle`'s own tests).
final class WebBlobAudioSource implements InMemoryAudioSource {
  new({BlobUrlLifecycle? lifecycle})
    : _lifecycle = lifecycle ?? BlobUrlLifecycle();

  final BlobUrlLifecycle _lifecycle;
  String? _objectUrl;

  @override
  Future<Uri> prepare(Uint8List bytes, String mimeType) async {
    await release();
    assert(
      _lifecycle.shouldCreate,
      'WebBlobAudioSource.prepare() called without releasing the previous '
      'blob URL first.',
    );
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);
    _objectUrl = url;
    _lifecycle.markCreated();
    return Uri.parse(url);
  }

  @override
  Future<void> release() async {
    final url = _objectUrl;
    _objectUrl = null;
    if (url == null || !_lifecycle.shouldRevoke) return;
    web.URL.revokeObjectURL(url);
    _lifecycle.markRevoked();
  }
}
