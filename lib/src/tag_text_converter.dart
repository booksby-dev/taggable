import 'dart:async';

import 'package:flutter/material.dart';

import 'utils/tag_style.dart';

/// A utility function that converts a tag text into a list of inline spans.
///
/// You can use this to convert a string containing tags (in the backend format)
/// into a list of inline spans, where each tag is represented by a custom
/// widget.
///
/// Typically, the [tagStyles] list is the same as the one used in the creation
/// of the tag text to parse the tags. The [backendToTaggable] function is used
/// to convert the backend string into a taggable object and may be asynchronous.
///
/// Usage:
/// ```dart
/// return convertTagTextToInlineSpans<Taggable>(
///   backendFormat,
///   tagStyles: _controller.tagStyles,
///   backendToTaggable: backendToTaggable,
///   taggableToInlineSpan: (taggable, tagStyle) {
///     return TextSpan(
///       text: '${tagStyle.prefix}${taggable.name}',
///       style: tagStyle.textStyle,
///       recognizer: TapGestureRecognizer()
///         ..onTap = () => ScaffoldMessenger.of(context).showSnackBar(
///               SnackBar(
///                 content: Text(
///                   'Tapped ${taggable.name} with id ${taggable.id}',
///                 ),
///                 duration: const Duration(seconds: 2),
///               ),
///             ),
///     );
///   },
/// );
/// ```
Future<List<InlineSpan>> convertTagTextToInlineSpans<T>(
  String text, {
  required List<TagStyle> tagStyles,
  required FutureOr<T?> Function(String prefix, String backendString)
      backendToTaggable,
  required InlineSpan Function(T taggable, TagStyle tagStyle)
      taggableToInlineSpan,
}) async {
  debugPrint('CONVERTER: $text');
  final pattern = tagStyles
      .map((style) => '${RegExp.escape(style.prefix)}(${style.regExp})')
      .join('|');
  final spans = <InlineSpan>[];
  int position = 0;

  for (final match in RegExp(pattern).allMatches(text)) {
    final textBeforeTag = text.substring(position, match.start);
    spans.add(TextSpan(text: textBeforeTag));
    position = match.end;

    final tagStyle = tagStyles.firstWhere(
      (style) => match.group(0)!.startsWith(style.prefix),
    );
    final taggable = await backendToTaggable(
      tagStyle.prefix,
      match.group(0)!.substring(tagStyle.prefix.length),
    );

    if (taggable != null) {
      spans.add(taggableToInlineSpan(taggable, tagStyle));
    } else {
      spans.add(TextSpan(text: match.group(0)));
    }
  }
  if (text.substring(position).isNotEmpty) {
    spans.add(TextSpan(text: text.substring(position)));
  }
  return spans;
}
