/// Product poster: the thumbnail when there is one, otherwise the brand's craft-textured placeholder.
/// Posters are images only. Grids never load video.
library;

import 'package:flutter/material.dart';

import '../brand/brand.dart';

class ProductPoster extends StatelessWidget {
  final List<String> tags;
  final String? thumbnailUrl;

  /// Show the brand mark as a play hint (cards and the product page; not tiny thumbnails).
  final bool showMark;
  const ProductPoster({super.key, required this.tags, this.thumbnailUrl, this.showMark = false});

  @override
  Widget build(BuildContext context) {
    final placeholder = ProductPosterPlaceholder(tag: tags.firstOrNull, showMark: showMark);
    if (thumbnailUrl == null) return placeholder;
    return Image.network(
      thumbnailUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
      frameBuilder: (_, child, frame, sync) => frame == null && !sync ? placeholder : child,
    );
  }
}
