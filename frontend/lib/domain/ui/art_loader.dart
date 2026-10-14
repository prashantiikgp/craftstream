/// Load assets/config/ui/art.yml, validated by ArtSchema.
library;

import 'package:flutter/services.dart';

import '../../core/yaml_loader.dart';
import '../../schemas/ui/art_schema.dart';

Future<ArtSchema> loadArtRules({AssetBundle? bundle}) =>
    loadYamlAsset('ui/art.yml', ArtSchema.fromJson, bundle: bundle);
