// The mock follows the API's rules, so screens behave the same on mock and real data.
import 'package:craftstream/data/generated/models.dart';
import 'package:craftstream/data/mock/mock_store.dart';
import 'package:craftstream/data/upload/picked_video.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/harness.dart';

void main() {
  late MockStore store;
  setUp(() => store = quietMockStore());

  test('search returns ready products only, every word must match (prefixes count)', () {
    final all = store.search().items;
    expect(all, isNotEmpty);
    expect(all.map((p) => p.title), isNot(contains('Glazed serving bowl'))); // processing
    expect(store.search(q: 'clay mug').items.map((p) => p.title), ['Hand-thrown clay mug']);
    expect(store.search(q: 'pott').items.length, greaterThan(1));
    expect(store.search(q: 'zzz').items, isEmpty);
  });

  test('tag filter', () {
    expect(store.search(tag: 'brass').items.every((p) => p.tags.contains('brass')), isTrue);
  });

  test('paging works like the API: cursor = last id of the page, null on the last page', () {
    final all = store.search(limit: 100).items.map((p) => p.id).toList();
    expect(all.length, greaterThan(5));
    final seen = <String>[];
    String? cursor;
    do {
      final page = store.search(limit: 5, cursor: cursor);
      expect(page.items.length, lessThanOrEqualTo(5));
      seen.addAll(page.items.map((p) => p.id));
      if (page.nextCursor != null) expect(page.nextCursor, page.items.last.id);
      cursor = page.nextCursor;
    } while (cursor != null);
    expect(seen, all); // every product once, in order
    expect(store.search(limit: all.length).nextCursor, isNull); // exactly one full page: no next
    expect(store.search(cursor: 'no-such-id').items, isEmpty);
  });

  test('orders compute the total and only for ready products', () {
    final order = store.placeOrder(const OrderCreate(productId: 'p_01', buyerName: 'Asha', quantity: 3));
    expect(order.total, 1350);
    expect(order.status, 'placed');
    expect(
      () => store.placeOrder(const OrderCreate(productId: 'p_13', buyerName: 'Asha', quantity: 1)),
      throwsStateError,
    );
  });

  test('an upload goes awaiting_upload -> processing -> ready', () {
    final ticket = store.createListing(
      const ProductCreate(title: 'Test pot', description: 'd', price: 10, currency: 'INR', tags: [], artisanName: 'A'),
    );
    const video = PickedVideo(name: 'v.mp4', sizeBytes: 100, mimeType: 'video/mp4');
    expect(store.product(ticket.product.id).videoStatus, 'awaiting_upload');
    store.sendChunk(ticket, video, 0, 60);
    expect(store.confirmedOffset(ticket), 60);
    store.sendChunk(ticket, video, 60, 40);
    expect(store.myProducts().first.id, ticket.product.id);
    expect(store.product(ticket.product.id).videoStatus, 'ready'); // processingTime is zero
  });
}
