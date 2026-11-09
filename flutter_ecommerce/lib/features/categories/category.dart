class ProductCategory {
  const ProductCategory({required this.documentId, required this.name});

  final String documentId;
  final String name;

  factory ProductCategory.fromJson(Map<String, Object?> json) {
    final documentId = json['documentId'];
    final name = json['name'];
    if (documentId is! String || name is! String) {
      throw const FormatException('Invalid Strapi category document.');
    }
    return ProductCategory(documentId: documentId, name: name);
  }
}
