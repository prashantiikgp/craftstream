// Discover loads one page at a time and appends the next on "Show more", the same way on mock and real
// data (the cursor is the API's). Pages are capped at 5 here so the 12 mock products span three pages.
import 'dart:async';

import 'package:craftstream/core/config.dart';
import 'package:craftstream/data/generated/models.dart';
import 'package:craftstream/data/mock/mock_store.dart';
import 'package:craftstream/data/providers.dart';
import 'package:craftstream/data/repositories/catalog_repository.dart';
import 'package:craftstream/features/discover/discover_controller.dart';
import 'package:craftstream/features/discover/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

const pageCap = 5;

/// MockStore search with small pages, a switch to fail the next call and an optional gate to hold one.
class PagingRepo implements CatalogRepository {
  final MockStore store = MockStore(latency: Duration.zero, chunkDelay: Duration.zero, processingTime: Duration.zero);
  bool failNext = false;
  Completer<void>? gate;
  final cursors = <String?>[];

  @override
  Future<ProductPage> search({String? q, String? tag, String? cursor, int? limit}) async {
    cursors.add(cursor);
    if (gate != null) await gate!.future;
    if (failNext) {
      failNext = false;
      throw StateError('network down');
    }
    return store.search(q: q, tag: tag, cursor: cursor, limit: pageCap);
  }

  @override
  Future<Product> product(String id) async => store.product(id);

  @override
  Future<List<String>> tags() async => store.tags();
}

/// A catalog with nothing live yet.
class EmptyRepo extends PagingRepo {
  @override
  Future<ProductPage> search({String? q, String? tag, String? cursor, int? limit}) async =>
      const ProductPage(items: [], nextCursor: null);

  @override
  Future<List<String>> tags() async => const [];
}

/// Scrolls to the end of Discover (so the button clears any bottom bar) and taps [label].
Future<void> tapShowMore(WidgetTester tester, String label) async {
  final button = find.text(label);
  final list = find.byType(Scrollable).first;
  await tester.scrollUntilVisible(button, 300, scrollable: list);
  await tester.drag(list, const Offset(0, -600));
  await settle(tester);
  await tester.tap(button);
  await settle(tester);
}

void main() {
  late AppConfig config, dark;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    config = await testConfig();
    dark = await testConfig(mode: 'dark');
  });

  late PagingRepo repo;
  late ProviderContainer container;
  setUp(() {
    repo = PagingRepo();
    container = ProviderContainer(
      overrides: [appConfigProvider.overrideWithValue(config), catalogRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
  });

  List<String> allReadyIds() => repo.store.search(limit: 100).items.map((p) => p.id).toList();
  DiscoverFeedController feedCtl() => container.read(discoverFeedProvider.notifier);

  test('pages append in API order until the cursor runs out', () async {
    final sub = container.listen(discoverFeedProvider, (_, _) {});
    addTearDown(sub.close);
    var feed = await container.read(discoverFeedProvider.future);
    expect(feed.items.length, pageCap);
    expect(feed.hasMore, isTrue);
    while (feed.hasMore) {
      await feedCtl().loadMore();
      feed = container.read(discoverFeedProvider).requireValue;
    }
    expect(feed.items.map((p) => p.id).toList(), allReadyIds());
    expect(repo.cursors.first, isNull);
    expect(repo.cursors.skip(1), everyElement(isNotNull));

    // Nothing left: another call does not fetch.
    final calls = repo.cursors.length;
    await feedCtl().loadMore();
    expect(repo.cursors.length, calls);
  });

  test('a failed "Show more" keeps the loaded results, and retrying continues from the same cursor', () async {
    final sub = container.listen(discoverFeedProvider, (_, _) {});
    addTearDown(sub.close);
    final first = await container.read(discoverFeedProvider.future);
    repo.failNext = true;
    await feedCtl().loadMore();
    var feed = container.read(discoverFeedProvider).requireValue;
    expect(feed.moreFailed, isTrue);
    expect(feed.items.length, pageCap);
    await feedCtl().loadMore();
    feed = container.read(discoverFeedProvider).requireValue;
    expect(feed.moreFailed, isFalse);
    expect(feed.items.length, pageCap * 2);
    expect(repo.cursors.sublist(1), [first.nextCursor, first.nextCursor]);
  });

  test('a new search during "Show more" wins: the late page is not appended to it', () async {
    final sub = container.listen(discoverFeedProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(discoverFeedProvider.future);
    repo.gate = Completer();
    final more = feedCtl().loadMore();
    container.read(discoverControllerProvider.notifier).setText('clay mug');
    final next = container.read(discoverFeedProvider.future);
    repo.gate!.complete();
    await more;
    final feed = await next;
    expect(feed.items.map((p) => p.title), ['Hand-thrown clay mug']);
    expect(container.read(discoverFeedProvider).requireValue.items.length, 1);
  });

  testWidgets('Discover shows "Show more" until everything is loaded', (tester) async {
    final container = await pumpApp(
      tester,
      config,
      overrides: [catalogRepositoryProvider.overrideWithValue(PagingRepo())],
    );
    final total = allReadyIds().length;
    expect(find.text(str(config, 'discover.count_more', {'count': pageCap})), findsOneWidget);

    int loaded() => container.read(discoverFeedProvider).requireValue.items.length;

    await tapShowMore(tester, str(config, 'discover.load_more'));
    expect(loaded(), pageCap * 2);
    await tapShowMore(tester, str(config, 'discover.load_more'));
    expect(loaded(), total);
    expect(find.text(str(config, 'discover.load_more')), findsNothing);
    await tester.scrollUntilVisible(find.byType(TextField), -300, scrollable: find.byType(Scrollable).first);
    expect(find.text(str(config, 'discover.count_many', {'count': total})), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed "Show more" offers a retry and keeps the cards', (tester) async {
    final failing = PagingRepo();
    await pumpApp(tester, config, overrides: [catalogRepositoryProvider.overrideWithValue(failing)]);
    failing.failNext = true;
    await tapShowMore(tester, str(config, 'discover.load_more'));
    expect(find.text(str(config, 'discover.load_more_failed')), findsOneWidget);
    expect(find.byType(ProductCard), findsWidgets);
    await tapShowMore(tester, str(config, 'common.retry'));
    expect(find.text(str(config, 'discover.load_more_failed')), findsNothing);
    expect(failing.cursors.length, 3); // first page, the failed one, the retry
  });

  testWidgets('an empty catalog says so, with nothing to clear', (tester) async {
    await pumpApp(tester, config, overrides: [catalogRepositoryProvider.overrideWithValue(EmptyRepo())]);
    expect(find.text(str(config, 'discover.none_title')), findsOneWidget);
    expect(find.text(str(config, 'discover.empty_title')), findsNothing);
    expect(find.text(str(config, 'discover.clear_filters')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a search with no matches offers to clear the filters', (tester) async {
    final container = await pumpApp(
      tester,
      config,
      overrides: [catalogRepositoryProvider.overrideWithValue(PagingRepo())],
    );
    container.read(discoverControllerProvider.notifier).setText('zzzz');
    await settle(tester);
    expect(find.text(str(config, 'discover.empty_title')), findsOneWidget);
    expect(find.text(str(config, 'discover.none_title')), findsNothing);
    await tester.tap(find.text(str(config, 'discover.clear_filters')));
    await settle(tester);
    expect(find.byType(ProductCard), findsWidgets);
  });

  // Tablet portrait and landscape, with the button and a full feed, light and dark: no overflow.
  for (final size in const [Size(820, 1180), Size(1180, 820)]) {
    for (final mode in ['light', 'dark']) {
      testWidgets('Discover with paging at ${size.width.toInt()}x${size.height.toInt()} $mode', (tester) async {
        final c = mode == 'light' ? config : dark;
        await pumpApp(tester, c, size: size, overrides: [catalogRepositoryProvider.overrideWithValue(PagingRepo())]);
        expect(tester.takeException(), isNull);
        expect(find.byType(ProductCard), findsWidgets);
        await tapShowMore(tester, str(c, 'discover.load_more'));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
