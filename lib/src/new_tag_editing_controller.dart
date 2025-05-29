import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'constants/constants.dart';
import 'utils/tag_style.dart';
import 'utils/tag.dart';

class NewTagEditingController<Taggable> extends TextEditingController {
  NewTagEditingController({
    required this.allTags,
    this.tagTapped,
  }) : super() {
    //addListener(taggingListeners);
    //ServicesBinding.instance.keyboard.addHandler(_onKey);
  }
  final List<Taggable> allTags;
  final Function(Taggable tag)? tagTapped;

  List<Taggable> selectedTags = [];

  @override
  void dispose() {
    //ServicesBinding.instance.keyboard.removeHandler(_onKey);
    removeListener(taggingListeners);
    super.dispose();
  }

  @override
  void clear() {
    super.clear();
  }

  /// A listener that triggers all tagging-related listeners.
  void taggingListeners() {
    updateText();

    // if (didPressDeleteKey) {
    //   didPressDeleteKey = false;
    //   _checkTagRecognizabilityController();
    // }
    // //_checkTagRecognizabilityController();
    // _cursorController();
    // final query = _checkTagQueryController();
    
    // if (query != null) {
    //   _availableTaggablesController(query.$1, query.$2);
    // }
  }

  void updateText() {
    final textSpanChildren = <InlineSpan>[];
    int position = 0;

    
  }

  TextSelection previousCursor = const TextSelection.collapsed(offset: 0);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<InlineSpan> textSpanChildren = <InlineSpan>[];
    int position = 0;

    for (final match in _getTagMatches(text)) {
      final textBeforeTag = text.substring(position, match.start);
      textSpanChildren.add(TextSpan(text: textBeforeTag));

      position = match.end;

      final tag = _parseTagString(match.group(0)!);
      if (tag == null) {
        textSpanChildren.add(TextSpan(text: match.group(0)));
        continue;
      }
      final tagText = tag.toModifiedString(
        toFrontendConverter,
        toBackendConverter,
        isFrontend: true,
      );

      final textStyle =
          textStyleBuilder?.call(context, tag.style.prefix, tag.taggable) ??
              style;
      // The Flutter engine does not render zero-width spaces with actual zero
      // width, so we need to split the tag into two parts: the leading space
      // markers and the actual tag text, while applying a zero letter spacing
      // to the former. This issue is tracked on the Flutter GitHub repository:
      // https://github.com/flutter/flutter/issues/160251
      final lastSpaceMarker = tagText.lastIndexOf(spaceMarker);

      if (lastSpaceMarker != -1) {
        textSpanChildren.add(TextSpan(
          text: tagText.substring(0, lastSpaceMarker + 1),
          style: const TextStyle(letterSpacing: 0),
        ));        

        textSpanChildren.add(stylizedTag(tagText.substring(lastSpaceMarker + 1), tag, textStyle));
        continue;
      }

      textSpanChildren.add(stylizedTag(tagText, tag, textStyle));
    }

    final textAfterAllTags = text.substring(position, text.length);
    textSpanChildren.add(TextSpan(text: textAfterAllTags));
    return TextSpan(style: style, children: textSpanChildren);
  }

  InlineSpan stylizedTag(String tagText, Tag tag, TextStyle? textStyle) {
    return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: InkWell(
            onTap: tag.style.onTapped != null ? () => tag.style.onTapped?.call(tag.taggable) : null,
            child: Container(
              decoration: BoxDecoration(
                color: !selectedTags.contains(tag.taggable) ? tag.style.tagColor : tag.style.highlightTagColor ?? tag.style.tagColor,
                borderRadius: BorderRadius.circular(4),
            ),
            padding: tag.style.tagColor == null ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 6),
            child: Text(tagText, style: textStyle),
          ),
        ),
    );
  }

  void setPreviousCursorPosition() {
    previousCursor = TextSelection(baseOffset: selection.baseOffset, extentOffset: selection.extentOffset);
  }

  /// A listener that ensures that the cursor is always outside of a tag.
  ///
  /// If the cursor is inside a tag, it is moved to the nearest side, unless the
  /// user moved into the tag with the arrow keys, in which case the cursor is
  /// moved to the other side.
  ///
  /// If a range is selected, any tags included in the range are selected as a whole.
  void _cursorController() {
  }
}
