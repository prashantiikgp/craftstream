/// Load assets/config/app/env_rules.yml, validated by EnvRulesSchema.
library;

import 'package:flutter/services.dart';

import '../../core/yaml_loader.dart';
import '../../schemas/app/env_rules_schema.dart';

Future<EnvRulesSchema> loadEnvRules({AssetBundle? bundle}) =>
    loadYamlAsset('app/env_rules.yml', EnvRulesSchema.fromJson, bundle: bundle);
