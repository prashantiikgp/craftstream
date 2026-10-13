/// Load assets/config/ui/strings.yml, validated by StringsSchema.
library;

import 'package:flutter/services.dart';

import '../../core/yaml_loader.dart';
import '../../schemas/ui/strings_schema.dart';

Future<StringsSchema> loadStringsRules({AssetBundle? bundle}) =>
    loadYamlAsset('ui/strings.yml', StringsSchema.fromJson, bundle: bundle);
