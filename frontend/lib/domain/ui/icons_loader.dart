/// Load assets/config/ui/icons.yml, validated by IconsSchema.
library;

import 'package:flutter/services.dart';

import '../../core/yaml_loader.dart';
import '../../schemas/ui/icons_schema.dart';

Future<IconsSchema> loadIconsRules({AssetBundle? bundle}) =>
    loadYamlAsset('ui/icons.yml', IconsSchema.fromJson, bundle: bundle);
