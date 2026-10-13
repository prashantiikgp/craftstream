/// Load assets/config/ui/theme.yml, validated by ThemeSchema.
library;

import 'package:flutter/services.dart';

import '../../core/yaml_loader.dart';
import '../../schemas/ui/theme_schema.dart';

Future<ThemeSchema> loadThemeRules({AssetBundle? bundle}) =>
    loadYamlAsset('ui/theme.yml', ThemeSchema.fromJson, bundle: bundle);
