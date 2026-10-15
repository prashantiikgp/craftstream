/// The activity log: reading it a page at a time (newest first, optionally one group, level or listing) and
/// reporting an upload step only the app sees.
library;

import '../generated/api_client.dart';
import '../generated/models.dart';

abstract interface class LogRepository {
  Future<LogPage> page({String? group, String? level, String? productId, String? cursor, int? limit});
  Future<LogEntry> report(LogEntryCreate entry);
}

class ApiLogRepository implements LogRepository {
  final ApiClient _api;
  const ApiLogRepository(this._api);

  @override
  Future<LogPage> page({String? group, String? level, String? productId, String? cursor, int? limit}) =>
      _api.listLogs(group: group, level: level, productId: productId, cursor: cursor, limit: limit);

  @override
  Future<LogEntry> report(LogEntryCreate entry) => _api.createLog(entry);
}
