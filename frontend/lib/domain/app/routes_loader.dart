/// Load assets/config/app/routes.yml, validated by RoutesSchema.
library;

import 'package:flutter/services.dart';

import '../../core/yaml_loader.dart';
import '../../schemas/app/routes_schema.dart';

Future<RoutesSchema> loadRoutesRules({AssetBundle? bundle}) =>
    loadYamlAsset('app/routes.yml', RoutesSchema.fromJson, bundle: bundle);
