/// Reads the rungs out of an HLS master playlist (`#EXT-X-STREAM-INF` lines). Android's player does not report
/// which rung it is on, only the picture size, so the overlay looks the bitrate up here by height.
library;

class Variant {
  final int bandwidthBps;
  final int? width, height;
  final String uri;
  const Variant({required this.bandwidthBps, this.width, this.height, required this.uri});
}

final _attr = RegExp(r'([A-Z0-9-]+)=("[^"]*"|[^,]*)');

/// Variants in playlist order. Lines that are not variants (audio renditions, comments) are skipped.
List<Variant> parseMasterPlaylist(String text) {
  final lines = text.split(RegExp(r'\r?\n')).map((l) => l.trim()).toList();
  final out = <Variant>[];
  for (var i = 0; i < lines.length; i++) {
    if (!lines[i].startsWith('#EXT-X-STREAM-INF:')) continue;
    final attrs = {
      for (final m in _attr.allMatches(lines[i].substring('#EXT-X-STREAM-INF:'.length))) m[1]!: m[2]!,
    };
    final uri = lines.skip(i + 1).firstWhere((l) => l.isNotEmpty && !l.startsWith('#'), orElse: () => '');
    final bandwidth = int.tryParse(attrs['BANDWIDTH'] ?? '');
    if (bandwidth == null || uri.isEmpty) continue;
    final res = (attrs['RESOLUTION'] ?? '').split('x');
    out.add(Variant(
      bandwidthBps: bandwidth,
      width: res.length == 2 ? int.tryParse(res[0]) : null,
      height: res.length == 2 ? int.tryParse(res[1]) : null,
      uri: uri,
    ));
  }
  return out;
}

/// The variant whose height is closest to [height] (the decoded picture can be a few pixels off).
Variant? variantForHeight(List<Variant> variants, int height) {
  Variant? best;
  for (final v in variants) {
    if (v.height == null) continue;
    if (best == null || (v.height! - height).abs() < (best.height! - height).abs()) best = v;
  }
  return best;
}

const _streamInf = '#EXT-X-STREAM-INF:';
const _media = '#EXT-X-MEDIA:';

Map<String, String> _attrs(String s) => {for (final m in _attr.allMatches(s)) m[1]!: m[2]!};
String _unquote(String? s) => (s ?? '').replaceAll('"', '');

/// A copy of the master playlist that keeps only the lowest-bandwidth variant and the one audio rendition it
/// needs (its group's DEFAULT=YES one, else the first), with every URI made absolute against [base] because the
/// copy travels to the player as a `data:` URI. Android's ExoPlayer gets this first, so it cannot start high
/// (see player.yml, `native_upswitch_*`). Returns null when there is nothing to trim (fewer than two variants).
String? lowestRungOnly(String master, Uri base) {
  final lines = master.split(RegExp(r'\r?\n')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  final variants = <({int line, int bandwidth})>[];
  for (var i = 0; i < lines.length; i++) {
    if (!lines[i].startsWith(_streamInf)) continue;
    final bw = int.tryParse(_attrs(lines[i].substring(_streamInf.length))['BANDWIDTH'] ?? '');
    if (bw != null) variants.add((line: i, bandwidth: bw));
  }
  if (variants.length < 2) return null;
  final keep = variants.reduce((a, b) => b.bandwidth < a.bandwidth ? b : a).line;
  final audioGroup = _unquote(_attrs(lines[keep].substring(_streamInf.length))['AUDIO']);

  // The audio rendition to keep: the group's default, else its first.
  int? audioLine;
  for (var i = 0; i < lines.length; i++) {
    if (!lines[i].startsWith(_media)) continue;
    final a = _attrs(lines[i].substring(_media.length));
    if (a['TYPE'] != 'AUDIO' || _unquote(a['GROUP-ID']) != audioGroup) continue;
    if (audioLine == null || _unquote(a['DEFAULT']) == 'YES') audioLine = i;
    if (_unquote(a['DEFAULT']) == 'YES') break;
  }

  String absolute(String uri) => base.resolve(uri).toString();
  String absoluteUriAttr(String line) =>
      line.replaceAllMapped(RegExp(r'URI="([^"]*)"'), (m) => 'URI="${absolute(m[1]!)}"');

  final out = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (l.startsWith(_streamInf)) {
      final uriLine = lines.indexWhere((x) => !x.startsWith('#'), i + 1);
      if (i == keep && uriLine != -1) {
        out.add(l);
        out.add(absolute(lines[uriLine]));
      }
      if (uriLine != -1) i = uriLine;
      continue;
    }
    if (!l.startsWith('#')) continue; // a stray URI line
    if (l.startsWith(_media)) {
      final isAudio = _attrs(l.substring(_media.length))['TYPE'] == 'AUDIO';
      if (isAudio && i != audioLine) continue;
      out.add(absoluteUriAttr(l));
      continue;
    }
    out.add(l); // #EXTM3U, #EXT-X-VERSION, #EXT-X-INDEPENDENT-SEGMENTS, ...
  }
  return '${out.join('\n')}\n';
}
