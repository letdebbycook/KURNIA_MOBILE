class Product {
  final int? idProduk;
  final String name;
  final String description;
  final double price;
  final String imageUrl;

  Product({
    this.idProduk,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
        'id_produk': idProduk,
        'nama': name,
        'deskripsi': description,
        'harga': price,
        'imageUrl': imageUrl,
      };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        idProduk: json['id_produk'] as int?,
        name: json['nama'] as String,
        description: json['deskripsi'] as String,
        price: (json['harga'] as num).toDouble(),
        imageUrl: json['imageUrl'] as String,
      );
}
