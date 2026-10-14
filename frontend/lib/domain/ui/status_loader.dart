/// Load assets/config/ui/status.yml, validated by StatusSchema.
library;

import 'package:flutter/services.dart';

import '../../core/yaml_loader.dart';
import '../../schemas/ui/status_schema.dart';

Future<StatusSchema> loadStatusRules({AssetBundle? bundle}) =>
    loadYamlAsset('ui/status.yml', StatusSchema.fromJson, bundle: bundle);
