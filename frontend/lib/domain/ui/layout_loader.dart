/// Load assets/config/ui/layout.yml, validated by LayoutSchema.
library;

import 'package:flutter/services.dart';

import '../../core/yaml_loader.dart';
import '../../schemas/ui/layout_schema.dart';

Future<LayoutSchema> loadLayoutRules({AssetBundle? bundle}) =>
    loadYamlAsset('ui/layout.yml', LayoutSchema.fromJson, bundle: bundle);
