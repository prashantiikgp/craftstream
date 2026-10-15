/// Load assets/config/logs/activity_log.yml, validated by ActivityLogSchema.
library;

import 'package:flutter/services.dart';

import '../../core/yaml_loader.dart';
import '../../schemas/logs/activity_log_schema.dart';

Future<ActivityLogSchema> loadActivityLogRules({AssetBundle? bundle}) =>
    loadYamlAsset('logs/activity_log.yml', ActivityLogSchema.fromJson, bundle: bundle);
