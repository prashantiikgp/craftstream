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
