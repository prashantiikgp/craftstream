/// The one place that chooses real or fake data. MOCK_DATA=true (dev) uses MockStore; otherwise the
/// generated API client. Screens and controllers only ever see the repository interfaces.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import 'api_provider.dart';
import 'logs/activity_reporter.dart';
import 'mock/mock_repositories.dart';
import 'mock/mock_store.dart';
import 'repositories/catalog_repository.dart';
import 'repositories/log_repository.dart';
import 'repositories/order_repository.dart';
import 'repositories/upload_repository.dart';
import 'upload/resumable_uploader.dart';
import 'upload/video_picker.dart';

bool _mock(Ref ref) => ref.watch(appConfigProvider).env.mockData;

/// Overridden in tests with zero delays.
final mockStoreProvider = Provider<MockStore>((ref) => MockStore());

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => _mock(ref)
      ? MockCatalogRepository(ref.watch(mockStoreProvider))
      : ApiCatalogRepository(ref.watch(apiClientProvider)),
);

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) =>
      _mock(ref) ? MockOrderRepository(ref.watch(mockStoreProvider)) : ApiOrderRepository(ref.watch(apiClientProvider)),
);

final uploadRepositoryProvider = Provider<UploadRepository>(
  (ref) => _mock(ref)
      ? MockUploadRepository(ref.watch(mockStoreProvider))
      : ApiUploadRepository(
          ref.watch(apiClientProvider),
          ResumableUploader(ref.watch(httpClientProvider), ref.watch(appConfigProvider).upload),
        ),
);

final videoPickerProvider = Provider<VideoPicker>(
  (ref) => _mock(ref) ? MockVideoPicker() : DeviceVideoPicker(ref.watch(appConfigProvider).upload),
);

final logRepositoryProvider = Provider<LogRepository>(
  (ref) =>
      _mock(ref) ? MockLogRepository(ref.watch(mockStoreProvider)) : ApiLogRepository(ref.watch(apiClientProvider)),
);

/// Reports upload steps to the activity log (logs/activity_log.yml); kept for the whole app session.
final activityReporterProvider = Provider<ActivityReporter>(
  (ref) => ActivityReporter(ref.watch(logRepositoryProvider), ref.watch(appConfigProvider).activityLog),
);
