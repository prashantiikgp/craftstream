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

  // What the Transcoder writes for our ladder: one audio group, DEFAULT=YES on the lowest audio rendition.
  const gcp = '''#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Test Language",DEFAULT=YES,AUTOSELECT=YES,URI="audio-ultra_low-fmp4.m3u8"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Test Language",URI="audio-high-fmp4.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=1534978,AVERAGE-BANDWIDTH=1503960,RESOLUTION=1280x720,AUDIO="audio",CODECS="avc1.4d001f,mp4a.40.5,mp4a.40.2"
video-high-fmp4.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=31964,AVERAGE-BANDWIDTH=29895,RESOLUTION=256x144,AUDIO="audio",CODECS="avc1.42000c,mp4a.40.5,mp4a.40.2"
video-ultra_low-fmp4.m3u8
''';

  test('the lowest-rung-only copy keeps one variant and its default audio, with absolute URIs', () {
    final base = Uri.parse('https://storage.googleapis.com/media/hls/p1/manifest.m3u8');
    final out = lowestRungOnly(gcp, base)!;
    expect(out, '''#EXTM3U
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Test Language",DEFAULT=YES,AUTOSELECT=YES,URI="https://storage.googleapis.com/media/hls/p1/audio-ultra_low-fmp4.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=31964,AVERAGE-BANDWIDTH=29895,RESOLUTION=256x144,AUDIO="audio",CODECS="avc1.42000c,mp4a.40.5,mp4a.40.2"
https://storage.googleapis.com/media/hls/p1/video-ultra_low-fmp4.m3u8
''');
    // It parses back as a one-rung ladder.
    expect(parseMasterPlaylist(out).map((v) => v.height), [144]);
  });

  test('the lowest-rung-only copy keeps version and CRLF playlists, and is null for a single rung', () {
    final base = Uri.parse('https://cdn.example/x/master.m3u8');
    final out = lowestRungOnly(transcoder, base)!;
    expect(out.split('\n'), [
      '#EXTM3U',
      '#EXT-X-VERSION:6',
      '#EXT-X-STREAM-INF:BANDWIDTH=46000,AVERAGE-BANDWIDTH=42000,CODECS="avc1.42c00b,mp4a.40.5",RESOLUTION=256x144,FRAME-RATE=12.000',
      'https://cdn.example/x/sd144.m3u8',
      '',
    ]);
    expect(lowestRungOnly('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=46000\nonly.m3u8\n', base), isNull);
  });
}
