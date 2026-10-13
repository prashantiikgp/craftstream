/// Load assets/config/media/upload.yml, validated by UploadSchema.
library;

import 'package:flutter/services.dart';

import '../../core/yaml_loader.dart';
import '../../schemas/media/upload_schema.dart';

Future<UploadSchema> loadUploadRules({AssetBundle? bundle}) =>
    loadYamlAsset('media/upload.yml', UploadSchema.fromJson, bundle: bundle);
