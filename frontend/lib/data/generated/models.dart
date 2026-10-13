// GENERATED FROM models/ BY tools/codegen.py. DO NOT EDIT BY HAND.
// ignore_for_file: type=lint

/// A buyer's order for one product.
class Order {
  final String id;
  final String productId;
  final String buyerName;
  final int quantity;
  final double total;
  final String status;
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.productId,
    required this.buyerName,
    required this.quantity,
    required this.total,
    required this.status,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        productId: json['product_id'] as String,
        buyerName: json['buyer_name'] as String,
        quantity: json['quantity'] as int,
        total: (json['total'] as num).toDouble(),
        status: json['status'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_id': productId,
        'buyer_name': buyerName,
        'quantity': quantity,
        'total': total,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Body for creating a Order.
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

/// Body for creating a Product.
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

class UploadTicket {
  final Product product;
  final String uploadUrl;
  final String uploadMethod;

  const UploadTicket({required this.product, required this.uploadUrl, required this.uploadMethod});

  factory UploadTicket.fromJson(Map<String, dynamic> json) => UploadTicket(
        product: Product.fromJson(json['product'] as Map<String, dynamic>),
        uploadUrl: json['upload_url'] as String,
        uploadMethod: json['upload_method'] as String,
      );
}
