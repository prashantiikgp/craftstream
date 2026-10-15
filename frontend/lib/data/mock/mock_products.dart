/// Sample listings for MOCK_DATA=true. Shapes come from the generated models, so they match the API.
library;

import '../generated/models.dart';

final _base = DateTime(2026, 10, 1, 10);

Product _p(
  int n,
  String title,
  String artisan,
  double price,
  List<String> tags,
  String description, {
  String status = 'ready',
}) => Product(
  id: 'p_${n.toString().padLeft(2, '0')}',
  title: title,
  description: description,
  price: price,
  currency: 'INR',
  tags: tags,
  artisanName: artisan,
  videoStatus: status,
  hlsUrl: status == 'ready' ? 'mock://media/p_$n/master.m3u8' : null,
  createdAt: _base.subtract(Duration(hours: n * 9)),
);

/// Listings the mock artisan (this device) owns: one live, one processing, one failed.
const mockMyProductIds = ['p_01', 'p_13', 'p_14'];

/// The artisan name the upload form starts with in mock mode.
const mockArtisanName = 'Meera Devi';

final mockProducts = <Product>[
  _p(
    1,
    'Hand-thrown clay mug',
    'Meera Devi',
    450,
    ['pottery', 'kitchen'],
    'Wheel-thrown from Khurja clay, dried for two days and fired twice. The video follows one mug from a lump '
        'of clay to the glaze kiln. Each piece is a little different.',
  ),
  _p(
    2,
    'Blue pottery planter',
    'Gopal Prajapat',
    1200,
    ['pottery', 'home'],
    'Jaipur blue pottery made from quartz paste, not clay. Watch the cobalt pattern painted freehand and '
        'the low firing that keeps the glaze glassy.',
  ),
  _p(
    3,
    'Kantha-stitched throw',
    'Rina Das',
    3800,
    ['textiles', 'kantha'],
    'Five layers of old cotton saris joined with running stitch. The video shows the motif traced, the '
        'layers basted and three weeks of stitching in twelve minutes.',
  ),
  _p(
    4,
    'Ikat silk stole',
    'Lakshmi Reddy',
    2450,
    ['textiles', 'ikat'],
    'Pochampally double ikat: the threads are tied and dyed before weaving, so the pattern appears on the '
        'loom. Watch the resist-tying and the first metres woven.',
  ),
  _p(
    5,
    'Channapatna wooden train',
    'Imran Pasha',
    890,
    ['woodwork', 'toys'],
    'Turned from ivory wood on a lathe and coloured with lac and vegetable dyes. Safe for small hands; no '
        'paint, no varnish.',
  ),
  _p(
    6,
    'Sheesham serving board',
    'Harish Suthar',
    1650,
    ['woodwork', 'kitchen'],
    'Cut from a single sheesham plank, hand-planed and finished with food-safe oil. The video shows the '
        'grain being read before the first cut.',
  ),
  _p(
    7,
    'Dhokra brass elephant',
    'Sukru Mal',
    2999,
    ['brass', 'dhokra'],
    'Lost-wax casting from Bastar: a clay core, beeswax threads, a clay mould, then molten brass. The wax '
        'model is destroyed, so no two are the same.',
  ),
  _p(
    8,
    'Bidri jewellery box',
    'Abdul Qadir',
    5400,
    ['metalwork', 'bidri'],
    'Zinc alloy inlaid with silver wire, then blackened with soil from the Bidar fort. Watch the pattern '
        'engraved and the silver hammered into the grooves.',
  ),
  _p(
    9,
    'Kundan drop earrings',
    'Neha Soni',
    6800,
    ['jewellery', 'kundan'],
    'Uncut glass stones set in gold foil the Bikaner way. The video shows the lac base, the foil pressed '
        'in and the enamel on the back.',
  ),
  _p(
    10,
    'Terracotta diya set of six',
    'Meera Devi',
    350,
    ['pottery', 'festive'],
    'Small oil lamps pinched and shaped by hand, sun-dried and fired in a wood kiln. Made in batches before '
        'Diwali.',
  ),
  _p(
    11,
    'Bamboo market basket',
    'Tomba Singh',
    780,
    ['bamboo', 'home'],
    'Split bamboo from Imphal woven in a twill pattern with a reinforced rim. The video shows the strips '
        'cut, smoothed and woven from the base up.',
  ),
  _p(
    12,
    'Hammered brass diya',
    'Salim Ansari',
    1150,
    ['brass', 'festive'],
    'Moradabad sheet brass shaped by hammer over a stake, then polished. Every dent is a hammer blow you '
        'can see in the video.',
  ),
  _p(
    13,
    'Glazed serving bowl',
    'Meera Devi',
    1250,
    ['pottery', 'kitchen'],
    'A wide bowl with a celadon glaze, thrown in one go.',
    status: 'processing',
  ),
  _p(
    14,
    'Clay water bottle',
    'Meera Devi',
    600,
    ['pottery', 'kitchen'],
    'Unglazed clay keeps water cool by evaporation.',
    status: 'failed',
  ),
];
