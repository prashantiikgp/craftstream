/// Load assets/config/app/navigation.yml, validated by NavigationSchema.
library;

import 'package:flutter/services.dart';

import '../../core/yaml_loader.dart';
import '../../schemas/app/navigation_schema.dart';

Future<NavigationSchema> loadNavigationRules({AssetBundle? bundle}) =>
    loadYamlAsset('app/navigation.yml', NavigationSchema.fromJson, bundle: bundle);
