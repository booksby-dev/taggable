import 'package:flutter/material.dart';

class Taggable {
  const Taggable({required this.id, required this.name});

  final String id;
  final String name;

  String getId() {
    return id.padRight(name.length - id.length, "_");
  }
}