/// Load assets/config/catalog/filters.yml, validated by FiltersSchema.
library;

import 'package:flutter/services.dart';

import '../../core/yaml_loader.dart';
import '../../schemas/catalog/filters_schema.dart';

Future<FiltersSchema> loadFiltersRules({AssetBundle? bundle}) =>
    loadYamlAsset('catalog/filters.yml', FiltersSchema.fromJson, bundle: bundle);
