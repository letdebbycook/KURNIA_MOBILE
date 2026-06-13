import 'dart:convert';
import 'package:flutter/material.dart';

class ProductImageHelper {
  static Widget buildProductImage(
    String imageUrl, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? errorWidget,
  }) {
    if (imageUrl.startsWith('data:image/')) {
      try {
        final commaIndex = imageUrl.indexOf(',');
        if (commaIndex != -1) {
          final base64Str = imageUrl.substring(commaIndex + 1);
          final bytes = base64Decode(base64Str);
          return Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            errorBuilder: (context, error, stackTrace) {
              return errorWidget ??
                  Container(
                    width: width,
                    height: height,
                    color: Colors.grey.shade100,
                    child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade400),
                  );
            },
          );
        }
      } catch (e) {
        debugPrint('Error decoding base64 image: $e');
      }
    }

    // Default network image loader
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ??
            Container(
              width: width,
              height: height,
              color: Colors.grey.shade100,
              child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade400),
            );
      },
    );
  }
}
