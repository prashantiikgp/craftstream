import 'package:craftstream/shared/player/master_playlist.dart';
import 'package:flutter_test/flutter_test.dart';

// The shape backend ladder_engine writes: lowest rung first, BANDWIDTH with 10% headroom.
const ours = '''#EXTM3U
#EXT-X-VERSION:7
#EXT-X-STREAM-INF:BANDWIDTH=47080,RESOLUTION=256x144
ultra_low/index.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=198000,RESOLUTION=640x360
low/index.m3u8
''';

// What the GCP Transcoder writes: more attributes, quoted CODECS with a comma, CRLF line ends.
const transcoder = '#EXTM3U\r\n#EXT-X-VERSION:6\r\n'
    '#EXT-X-STREAM-INF:BANDWIDTH=46000,AVERAGE-BANDWIDTH=42000,CODECS="avc1.42c00b,mp4a.40.5",RESOLUTION=256x144,FRAME-RATE=12.000\r\n'
    'sd144.m3u8\r\n'
    '#EXT-X-STREAM-INF:BANDWIDTH=850000,CODECS="avc1.4d401f,mp4a.40.2",RESOLUTION=1280x720\r\n'
    '\r\nhd720.m3u8\r\n';

void main() {
  test('reads every rung in order', () {
    final v = parseMasterPlaylist(ours);
    expect(v.map((e) => (e.height, e.bandwidthBps, e.uri)), [(144, 47080, 'ultra_low/index.m3u8'), (360, 198000, 'low/index.m3u8')]);
  });

  test('copes with quoted commas, extra attributes, CRLF and blank lines', () {
    final v = parseMasterPlaylist(transcoder);
    expect(v.map((e) => (e.width, e.height, e.bandwidthBps, e.uri)),
        [(256, 144, 46000, 'sd144.m3u8'), (1280, 720, 850000, 'hd720.m3u8')]);
  });

  test('a media playlist or junk has no variants', () {
    expect(parseMasterPlaylist('#EXTM3U\n#EXTINF:4.0,\nseg0.m4s\n'), isEmpty);
    expect(parseMasterPlaylist('#EXT-X-STREAM-INF:RESOLUTION=1x1\nx.m3u8\n'), isEmpty); // no BANDWIDTH
  });

  test('looks the rung up by the nearest height', () {
    final v = parseMasterPlaylist(ours);
    expect(variantForHeight(v, 144)?.bandwidthBps, 47080);
    expect(variantForHeight(v, 146)?.bandwidthBps, 47080); // decoders can report a few pixels off
    expect(variantForHeight(v, 352)?.bandwidthBps, 198000);
    expect(variantForHeight(const [], 144), isNull);
  });
}
