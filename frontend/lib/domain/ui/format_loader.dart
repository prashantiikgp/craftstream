/// Load assets/config/ui/format.yml, validated by FormatSchema.
library;

import 'package:flutter/services.dart';

import '../../core/yaml_loader.dart';
import '../../schemas/ui/format_schema.dart';

Future<FormatSchema> loadFormatRules({AssetBundle? bundle}) =>
    loadYamlAsset('ui/format.yml', FormatSchema.fromJson, bundle: bundle);
