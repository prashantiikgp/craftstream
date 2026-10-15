// GENERATED FROM models/ BY tools/codegen.py. DO NOT EDIT BY HAND.
// ignore_for_file: type=lint

/// The body of every error response.
class ErrorResponse {
  final String code;
  final String message;
  final List<String> details;

  const ErrorResponse({
    required this.code,
    required this.message,
    required this.details,
  });

  factory ErrorResponse.fromJson(Map<String, dynamic> json) => ErrorResponse(
        code: json['code'] as String,
        message: json['message'] as String,
        details: ((json['details'] ?? []) as List).cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        'details': details,
      };
}

/// One key and value on an activity log entry.
class LogDetail {
  final String key;
  final String value;

  const LogDetail({
    required this.key,
    required this.value,
  });

  factory LogDetail.fromJson(Map<String, dynamic> json) => LogDetail(
        key: json['key'] as String,
        value: json['value'] as String,
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'value': value,
      };
}

/// One step in the activity log (an upload, a video, an order).
class LogEntry {
  final String id;
  final String event;
  final String? productId;
  final String? orderId;
  final List<LogDetail> details;
  final String level;
  final String group;
  final String source;
  final String message;
  final DateTime at;

  const LogEntry({
    required this.id,
    required this.event,
    this.productId,
    this.orderId,
    required this.details,
    required this.level,
    required this.group,
    required this.source,
    required this.message,
    required this.at,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
        id: json['id'] as String,
        event: json['event'] as String,
        productId: json['product_id'] == null ? null : json['product_id'] as String,
        orderId: json['order_id'] == null ? null : json['order_id'] as String,
        details: ((json['details'] ?? []) as List).map((e) => LogDetail.fromJson(e as Map<String, dynamic>)).toList(),
        level: json['level'] as String,
        group: json['group'] as String,
        source: json['source'] as String,
        message: json['message'] as String,
        at: DateTime.parse(json['at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'event': event,
        'product_id': productId,
        'order_id': orderId,
        'details': details.map((e) => e.toJson()).toList(),
        'level': level,
        'group': group,
        'source': source,
        'message': message,
        'at': at.toIso8601String(),
      };
}

/// Request body to create a new LogEntry (server-set fields excluded).
class LogEntryCreate {
  final String event;
  final String? productId;
  final String? orderId;
  final List<LogDetail> details;

  const LogEntryCreate({
    required this.event,
    this.productId,
    this.orderId,
    required this.details,
  });

  factory LogEntryCreate.fromJson(Map<String, dynamic> json) => LogEntryCreate(
        event: json['event'] as String,
        productId: json['product_id'] == null ? null : json['product_id'] as String,
        orderId: json['order_id'] == null ? null : json['order_id'] as String,
        details: ((json['details'] ?? []) as List).map((e) => LogDetail.fromJson(e as Map<String, dynamic>)).toList(),
      );

  Map<String, dynamic> toJson() => {
        'event': event,
        'product_id': productId,
        'order_id': orderId,
        'details': details.map((e) => e.toJson()).toList(),
      };
}

/// One page of the activity log, newest first.
class LogPage {
  final List<LogEntry> items;
  final String? nextCursor;

  const LogPage({
    required this.items,
    this.nextCursor,
  });

  factory LogPage.fromJson(Map<String, dynamic> json) => LogPage(
        items: ((json['items'] ?? []) as List).map((e) => LogEntry.fromJson(e as Map<String, dynamic>)).toList(),
        nextCursor: json['next_cursor'] == null ? null : json['next_cursor'] as String,
      );

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'next_cursor': nextCursor,
      };
}

/// A buyer's order for one product.
class Order {
  final String id;
  final String productId;
  final String buyerName;
  final int quantity;
  final double total;
  final String currency;
  final String status;
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.productId,
    required this.buyerName,
    required this.quantity,
    required this.total,
    required this.currency,
    required this.status,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        productId: json['product_id'] as String,
        buyerName: json['buyer_name'] as String,
        quantity: json['quantity'] as int,
        total: (json['total'] as num).toDouble(),
        currency: json['currency'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_id': productId,
        'buyer_name': buyerName,
        'quantity': quantity,
        'total': total,
        'currency': currency,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Request body to create a new Order (server-set fields excluded).
class OrderCreate {
  final String productId;
  final String buyerName;
  final int quantity;

  const OrderCreate({
    required this.productId,
    required this.buyerName,
    required this.quantity,
  });

  factory OrderCreate.fromJson(Map<String, dynamic> json) => OrderCreate(
        productId: json['product_id'] as String,
        buyerName: json['buyer_name'] as String,
        quantity: json['quantity'] as int,
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'buyer_name': buyerName,
        'quantity': quantity,
      };
}

/// A handmade product listed by an artisan, with a process video.
class Product {
  final String id;
  final String title;
  final String description;
  final double price;
  final String currency;
  final List<String> tags;
  final String artisanName;
  final String videoStatus;
  final String? hlsUrl;
  final String? thumbnailUrl;
  final DateTime createdAt;

  const Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.currency,
    required this.tags,
    required this.artisanName,
    required this.videoStatus,
    this.hlsUrl,
    this.thumbnailUrl,
    required this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        price: (json['price'] as num).toDouble(),
        currency: json['currency'] as String,
        tags: ((json['tags'] ?? []) as List).cast<String>(),
        artisanName: json['artisan_name'] as String,
        videoStatus: json['video_status'] as String,
        hlsUrl: json['hls_url'] == null ? null : json['hls_url'] as String,
        thumbnailUrl: json['thumbnail_url'] == null ? null : json['thumbnail_url'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'price': price,
        'currency': currency,
        'tags': tags,
        'artisan_name': artisanName,
        'video_status': videoStatus,
        'hls_url': hlsUrl,
        'thumbnail_url': thumbnailUrl,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Request body to create a new Product (server-set fields excluded).
class ProductCreate {
  final String title;
  final String description;
  final double price;
  final String currency;
  final List<String> tags;
  final String artisanName;

  const ProductCreate({
    required this.title,
    required this.description,
    required this.price,
    required this.currency,
    required this.tags,
    required this.artisanName,
  });

  factory ProductCreate.fromJson(Map<String, dynamic> json) => ProductCreate(
        title: json['title'] as String,
        description: json['description'] as String,
        price: (json['price'] as num).toDouble(),
        currency: json['currency'] as String,
        tags: ((json['tags'] ?? []) as List).cast<String>(),
        artisanName: json['artisan_name'] as String,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'price': price,
        'currency': currency,
        'tags': tags,
        'artisan_name': artisanName,
      };
}

/// A product as shown in search results (no description, no video URL).
class ProductSummary {
  final String id;
  final String title;
  final double price;
  final String currency;
  final List<String> tags;
  final String artisanName;
  final String? thumbnailUrl;

  const ProductSummary({
    required this.id,
    required this.title,
    required this.price,
    required this.currency,
    required this.tags,
    required this.artisanName,
    this.thumbnailUrl,
  });

  factory ProductSummary.fromJson(Map<String, dynamic> json) => ProductSummary(
        id: json['id'] as String,
        title: json['title'] as String,
        price: (json['price'] as num).toDouble(),
        currency: json['currency'] as String,
        tags: ((json['tags'] ?? []) as List).cast<String>(),
        artisanName: json['artisan_name'] as String,
        thumbnailUrl: json['thumbnail_url'] == null ? null : json['thumbnail_url'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'price': price,
        'currency': currency,
        'tags': tags,
        'artisan_name': artisanName,
        'thumbnail_url': thumbnailUrl,
      };
}

/// One page of search results.
class ProductPage {
  final List<ProductSummary> items;
  final String? nextCursor;

  const ProductPage({
    required this.items,
    this.nextCursor,
  });

  factory ProductPage.fromJson(Map<String, dynamic> json) => ProductPage(
        items: ((json['items'] ?? []) as List).map((e) => ProductSummary.fromJson(e as Map<String, dynamic>)).toList(),
        nextCursor: json['next_cursor'] == null ? null : json['next_cursor'] as String,
      );

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
        'next_cursor': nextCursor,
      };
}

/// Tags that currently have at least one ready product, most used first.
class TagList {
  final List<String> tags;

  const TagList({
    required this.tags,
  });

  factory TagList.fromJson(Map<String, dynamic> json) => TagList(
        tags: ((json['tags'] ?? []) as List).cast<String>(),
      );

  Map<String, dynamic> toJson() => {
        'tags': tags,
      };
}

/// What the app must check before it starts an upload.
class UploadPolicy {
  final int maxDurationSeconds;
  final List<String> allowedMimeTypes;
  final int chunkSizeBytes;

  const UploadPolicy({
    required this.maxDurationSeconds,
    required this.allowedMimeTypes,
    required this.chunkSizeBytes,
  });

  factory UploadPolicy.fromJson(Map<String, dynamic> json) => UploadPolicy(
        maxDurationSeconds: json['max_duration_seconds'] as int,
        allowedMimeTypes: ((json['allowed_mime_types'] ?? []) as List).cast<String>(),
        chunkSizeBytes: json['chunk_size_bytes'] as int,
      );

  Map<String, dynamic> toJson() => {
        'max_duration_seconds': maxDurationSeconds,
        'allowed_mime_types': allowedMimeTypes,
        'chunk_size_bytes': chunkSizeBytes,
      };
}

/// A new listing plus where and how to upload its video.
class UploadTicket {
  final Product product;
  final String uploadUrl;
  final String uploadMethod;
  final int chunkSizeBytes;

  const UploadTicket({
    required this.product,
    required this.uploadUrl,
    required this.uploadMethod,
    required this.chunkSizeBytes,
  });

  factory UploadTicket.fromJson(Map<String, dynamic> json) => UploadTicket(
        product: Product.fromJson(json['product'] as Map<String, dynamic>),
        uploadUrl: json['upload_url'] as String,
        uploadMethod: json['upload_method'] as String,
        chunkSizeBytes: json['chunk_size_bytes'] as int,
      );

  Map<String, dynamic> toJson() => {
        'product': product.toJson(),
        'upload_url': uploadUrl,
        'upload_method': uploadMethod,
        'chunk_size_bytes': chunkSizeBytes,
      };
}
