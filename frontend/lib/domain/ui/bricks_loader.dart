/// Load assets/config/ui/bricks.yml, validated by BricksSchema.
library;

import 'package:flutter/services.dart';

import '../../core/yaml_loader.dart';
import '../../schemas/ui/bricks_schema.dart';

Future<BricksSchema> loadBricksRules({AssetBundle? bundle}) =>
    loadYamlAsset('ui/bricks.yml', BricksSchema.fromJson, bundle: bundle);
