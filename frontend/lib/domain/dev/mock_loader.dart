/// Load assets/config/dev/mock.yml, validated by MockSchema.
library;

import 'package:flutter/services.dart';

import '../../core/yaml_loader.dart';
import '../../schemas/dev/mock_schema.dart';

Future<MockSchema> loadMockRules({AssetBundle? bundle}) =>
    loadYamlAsset('dev/mock.yml', MockSchema.fromJson, bundle: bundle);
