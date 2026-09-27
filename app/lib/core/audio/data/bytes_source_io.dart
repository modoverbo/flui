import 'dart:io';
import 'dart:typed_data';

import 'package:flui/core/audio/data/bytes_source.dart';
import 'package:path_provider/path_provider.dart';

InMemoryAudioSource createInMemoryAudioSource() => TempFileAudioSource();

/// Writes in-memory bytes to a uniquely-named temp file so `just_audio` can
/// open a `file://` source on Android/iOS (U3 spike: `StreamAudioSource`
/// fails there without relaxing cleartext, which this change does not do;
/// a temp file passes as-is).
///
/// The temp-directory resolver is injectable (constructor's
/// `temporaryDirectory` parameter) so unit tests never depend on
/// `path_provider`'s platform channel — only on real, disposable `dart:io`
/// file operations against an already-resolved directory.
final class TempFileAudioSource implements InMemoryAudioSource {
  new({Future<Directory> Function()? temporaryDirectory})
    : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;

  final Future<Directory> Function() _temporaryDirectory;
  File? _file;

  @override
  Future<Uri> prepare(Uint8List bytes, String mimeType) async {
    await release();
    final dir = await _temporaryDirectory();
    final name =
        'flui_speech_player_${DateTime.now().microsecondsSinceEpoch}_'
        '${identityHashCode(this)}${_extensionFor(mimeType)}';
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(bytes, flush: true);
    _file = file;
    return file.uri;
  }

  @override
  Future<void> release() async {
    final file = _file;
    _file = null;
    if (file == null) return;
    if (file.existsSync()) await file.delete();
  }

  String _extensionFor(String mimeType) => switch (mimeType) {
    'audio/wav' => '.wav',
    'audio/webm' => '.webm',
    'audio/ogg' => '.ogg',
    'audio/mp4' => '.mp4',
    _ => '.tmp',
  };
}
