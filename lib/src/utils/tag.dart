import 'package:flutter_taggable/src/constants/constants.dart';

import 'tag_style.dart';

/// A utility class that represents a tag in the form of a tagged object and a tag style.
class Tag<T> {
  Tag({required this.taggable, this.style = const TagStyle()});

  /// The tagged object.
  final T taggable;

  /// The style of the tag, containing the prefix and the text style.
  final TagStyle style;

  /// Converts the taggable object to a string for the frontend or backend.
  ///
  /// Important: the backend string created by this method is not the true backend
  /// representation of the tag. Both frontend and backend strings are modified
  /// to have the same length, so that the frontend text field's cursor behaviour
  /// matches the [TagTextEditingController]'s internal cursor behaviour. This is
  /// done by inserting zero-width spaces in the representation that is shorter.
  String toModifiedString(
    String Function(T taggable) toFrontendConverter,
    String Function(T taggable) toBackendConverter, {
    required bool isFrontend,
  }) {
    final frontendString = toFrontendConverter(taggable);
    final backendString = toBackendConverter(taggable);
    if (isFrontend) {
      final lengthDifference = (backendString.length)
          .clamp(0, backendString.length);
      return '${spaceMarker * lengthDifference}${style.showPrefix ? style.prefix : ''}$frontendString';
    } else {
      final lengthDifference = (frontendString.length + (style.showPrefix ? 0 : -1) - backendString.length)
          .clamp(0, frontendString.length);
      return '${style.prefix}${spaceMarker * lengthDifference}$backendString';
    }
  }
}
