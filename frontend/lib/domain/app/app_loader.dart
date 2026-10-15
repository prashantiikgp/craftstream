/// Load assets/config/app/app.yml, validated by AppSchema.
library;

import 'package:flutter/services.dart';

import '../../core/yaml_loader.dart';
import '../../schemas/app/app_schema.dart';

Future<AppSchema> loadAppRules({AssetBundle? bundle}) =>
    loadYamlAsset('app/app.yml', AppSchema.fromJson, bundle: bundle);
