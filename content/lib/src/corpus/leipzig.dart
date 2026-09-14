import 'dart:convert';
import 'dart:io';

import 'package:content/src/corpus/cooccurrence.dart';
import 'package:path/path.dart' as p;

/// Which slice of Spanish a Leipzig package represents.
enum CorpusRole {
  /// A country subcorpus, used for the dispersion measure.
  country,

  /// Formal written Spanish (news, wikipedia) for the pedantry proxy.
  formal,

  /// Open web Spanish, the informal side of the pedantry proxy.
  informal,
}

final class LeipzigPackage {
  const LeipzigPackage(this.name, this.role, {this.country});

  final String name;
  final CorpusRole role;
  final String? country;

  String get url =>
      'https://downloads.wortschatz-leipzig.de/corpora/$name.tar.gz';

  String get wordsMember => '$name/$name-words.txt';

  /// Sentence co-occurrence: `id1 id2 frequency significance`.
  String get cooccurrenceMember => '$name/$name-co_s.txt';

  /// Immediate-neighbour co-occurrence, same columns. Adjacency is the
  /// closest thing the packages give to a syntactic slot.
  String get neighbourMember => '$name/$name-co_n.txt';
}

/// The packages the pool is built from.
///
/// Verified to exist on downloads.wortschatz-leipzig.de on 2026-09-13. Leipzig
/// has no `spa-es`, `spa-cl` or `spa-bo` subcorpus, so peninsular and Chilean
/// Spanish only reach the pool through the pan-Hispanic web and news mixes;
/// `content/data/LICENSES.md` records that limitation.
const defaultPackages = <LeipzigPackage>[
  LeipzigPackage('spa-ar_web_2016_100K', CorpusRole.country, country: 'ar'),
  LeipzigPackage('spa-co_web_2015_100K', CorpusRole.country, country: 'co'),
  LeipzigPackage('spa-cr_web_2015_100K', CorpusRole.country, country: 'cr'),
  LeipzigPackage('spa-cu_web_2015_100K', CorpusRole.country, country: 'cu'),
  LeipzigPackage('spa-do_web_2015_100K', CorpusRole.country, country: 'do'),
  LeipzigPackage('spa-ec_web_2015_100K', CorpusRole.country, country: 'ec'),
  LeipzigPackage('spa-gt_web_2015_100K', CorpusRole.country, country: 'gt'),
  LeipzigPackage('spa-hn_web_2015_100K', CorpusRole.country, country: 'hn'),
  LeipzigPackage('spa-mx_web_2015_100K', CorpusRole.country, country: 'mx'),
  LeipzigPackage('spa-ni_web_2015_100K', CorpusRole.country, country: 'ni'),
  LeipzigPackage('spa-pa_web_2016_100K', CorpusRole.country, country: 'pa'),
  LeipzigPackage('spa-pe_web_2016_100K', CorpusRole.country, country: 'pe'),
  LeipzigPackage('spa-pr_web_2016_100K', CorpusRole.country, country: 'pr'),
  LeipzigPackage('spa-py_web_2016_100K', CorpusRole.country, country: 'py'),
  LeipzigPackage('spa-sv_web_2016_100K', CorpusRole.country, country: 'sv'),
  LeipzigPackage('spa-uy_web_2016_100K', CorpusRole.country, country: 'uy'),
  LeipzigPackage('spa-ve_web_2016_100K', CorpusRole.country, country: 've'),
  LeipzigPackage('spa_news_2023_100K', CorpusRole.formal),
  LeipzigPackage('spa_wikipedia_2021_100K', CorpusRole.formal),
  // spa_web_2016_100K is skipped on purpose: Leipzig's extraction for that
  // package dropped accents ("ficcin" for "ficción"), which poisons both the
  // lemma folding and the pedantry proxy. The 2011 and 2012 web packages are
  // clean.
  LeipzigPackage('spa_web_2012_100K', CorpusRole.informal),
  LeipzigPackage('spa_web_2011_100K', CorpusRole.informal),
];

/// Fetches a package's word-frequency table. Injectable so tests stay offline.
// A single-method interface on purpose: it is the seam that keeps the tests
// off the network.
// ignore: one_member_abstracts
abstract class CorpusSource {
  const CorpusSource();

  /// `surface -> frequency` for one package.
  Future<Map<String, int>> wordFrequencies(LeipzigPackage package);

  /// `id -> surface` for one package, or null when unavailable.
  Future<Map<int, String>?> wordIds(LeipzigPackage package) async => null;

  /// Raw `co_s.txt` for one package, or null when unavailable.
  Future<String?> cooccurrences(LeipzigPackage package) async => null;

  /// Raw `co_n.txt` for one package, or null when unavailable.
  Future<String?> neighbours(LeipzigPackage package) async => null;
}

/// Downloads (and caches) the `.tar.gz` and reads its `-words.txt` member.
///
/// Extraction shells out to `tar`, which every supported dev machine has; that
/// keeps the package free of an archive dependency.
final class LeipzigDownloader extends CorpusSource {
  LeipzigDownloader({required this.cacheDir, this.log});

  final String cacheDir;
  final void Function(String message)? log;
  final HttpClient _client = HttpClient();

  @override
  Future<Map<String, int>> wordFrequencies(LeipzigPackage package) async =>
      parseWordsFile(
        File(await _member(package, package.wordsMember, 'words'))
            .readAsStringSync(),
      );

  @override
  Future<Map<int, String>?> wordIds(LeipzigPackage package) async =>
      parseWordIds(
        File(await _member(package, package.wordsMember, 'words'))
            .readAsStringSync(),
      );

  @override
  Future<String?> cooccurrences(LeipzigPackage package) async =>
      _readMember(package, package.cooccurrenceMember, 'co_s');

  @override
  Future<String?> neighbours(LeipzigPackage package) async =>
      _readMember(package, package.neighbourMember, 'co_n');

  Future<String?> _readMember(
    LeipzigPackage package,
    String member,
    String suffix,
  ) async {
    try {
      return File(await _member(package, member, suffix)).readAsStringSync();
    } on Object catch (error) {
      log?.call('no $suffix table for ${package.name}: $error');
      return null;
    }
  }

  /// Ensures one member of the package archive is on disk and returns its
  /// path. The archive itself is downloaded once and kept.
  Future<String> _member(
    LeipzigPackage package,
    String member,
    String suffix,
  ) async {
    final target = File(p.join(cacheDir, '${package.name}-$suffix.txt'));
    if (target.existsSync()) return target.path;
    final archive = File(p.join(cacheDir, '${package.name}.tar.gz'));
    if (!archive.existsSync()) {
      log?.call('downloading ${package.name}');
      await _download(package.url, archive);
    }
    log?.call('extracting $suffix from ${package.name}');
    final extracted = await Process.run('tar', [
      '-xzf',
      archive.path,
      '-C',
      cacheDir,
      member,
    ]);
    if (extracted.exitCode != 0) {
      throw StateError('tar failed for $member: ${extracted.stderr}');
    }
    File(p.join(cacheDir, member)).renameSync(target.path);
    final unpacked = Directory(p.join(cacheDir, package.name));
    if (unpacked.existsSync()) unpacked.deleteSync(recursive: true);
    return target.path;
  }

  Future<void> _download(String url, File target) async {
    Directory(cacheDir).createSync(recursive: true);
    final request = await _client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != 200) {
      throw StateError('GET $url returned ${response.statusCode}');
    }
    final sink = target.openWrite();
    await response.pipe(sink);
  }
}

/// `rank \t word \t frequency`, one per line.
Map<String, int> parseWordsFile(String contents) {
  final counts = <String, int>{};
  for (final line in const LineSplitter().convert(contents)) {
    if (line.isEmpty) continue;
    final parts = line.split('\t');
    if (parts.length < 3) continue;
    final frequency = int.tryParse(parts[2].trim());
    if (frequency == null) continue;
    counts[parts[1]] = (counts[parts[1]] ?? 0) + frequency;
  }
  return counts;
}
