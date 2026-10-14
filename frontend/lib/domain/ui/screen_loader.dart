/// Load every assets/config/ui/screens/*.yml, each validated by ScreenSchema.
library;

import 'package:flutter/services.dart';

import '../../core/yaml_loader.dart';
import '../../schemas/ui/screen_schema.dart';

Future<Map<String, ScreenSchema>> loadScreenRules({AssetBundle? bundle}) =>
    loadYamlFolder('ui/screens', ScreenSchema.fromJson, bundle: bundle);
