class Product {
  const Product({
    required this.documentId,
    required this.title,
    required this.slug,
    this.description,
    this.imageUrl,
    this.imageUrls = const [],
    this.category,
    this.price,
  });

  final String documentId;
  final String title;
  final String slug;
  final String? description;
  final String? imageUrl;
  final List<String> imageUrls;
  final ProductCategorySummary? category;
  final double? price;

  factory Product.fromJson(
    Map<String, Object?> json, {
    required Uri Function(String path) resolveMediaUrl,
  }) {
    final documentId = json['documentId'];
    final title = json['title'];
    final slug = json['slug'];
    if (documentId is! String || title is! String || slug is! String) {
      throw const FormatException('Invalid Strapi product document.');
    }

    final rawPrice = json['price'];
    final price = rawPrice is num ? rawPrice.toDouble() : null;

    final imageUrls = _mediaUrls(json['images'], resolveMediaUrl);
    final primaryImageUrl = _mediaUrl(json['image'], resolveMediaUrl);
    final allImageUrls = <String>{
      ?primaryImageUrl,
      ...imageUrls,
    }.toList(growable: false);

    return Product(
      documentId: documentId,
      title: title,
      slug: slug,
      description: json['description'] is String
          ? json['description']! as String
          : null,
      imageUrl: allImageUrls.isEmpty ? null : allImageUrls.first,
      imageUrls: allImageUrls,
      category: _category(json['category']),
      price: price,
    );
  }

  static String? _mediaUrl(
    Object? value,
    Uri Function(String path) resolveMediaUrl,
  ) {
    final media = _unwrapRelation(value);
    if (media is! Map<String, Object?> || media['url'] is! String) {
      return null;
    }
    return resolveMediaUrl(media['url']! as String).toString();
  }

  static List<String> _mediaUrls(
    Object? value,
    Uri Function(String path) resolveMediaUrl,
  ) {
    if (value is! List<Object?>) return const [];
    return value
        .map((item) => _mediaUrl(item, resolveMediaUrl))
        .whereType<String>()
        .toList(growable: false);
  }

  static ProductCategorySummary? _category(Object? value) {
    final category = _unwrapRelation(value);
    if (category is! Map<String, Object?> ||
        category['documentId'] is! String ||
        category['name'] is! String) {
      return null;
    }
    return ProductCategorySummary(
      documentId: category['documentId']! as String,
      name: category['name']! as String,
    );
  }

  static Object? _unwrapRelation(Object? value) {
    if (value is Map<String, Object?> && value.containsKey('data')) {
      return value['data'];
    }
    return value;
  }
}

class ProductCategorySummary {
  const ProductCategorySummary({required this.documentId, required this.name});

  final String documentId;
  final String name;
}
