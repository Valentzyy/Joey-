import 'package:flutter/material.dart';

class CategoryItem {
  final String id;
  final String name;
  final String emoji;
  final int colorValue;

  const CategoryItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorValue,
  });

  Color get color => Color(colorValue);
}
