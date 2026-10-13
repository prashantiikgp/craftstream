/// Load assets/config/media/player.yml, validated by PlayerSchema.
library;

import 'package:flutter/services.dart';

import '../../core/yaml_loader.dart';
import '../../schemas/media/player_schema.dart';

Future<PlayerSchema> loadPlayerRules({AssetBundle? bundle}) =>
    loadYamlAsset('media/player.yml', PlayerSchema.fromJson, bundle: bundle);
