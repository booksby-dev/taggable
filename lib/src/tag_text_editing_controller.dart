import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'constants/constants.dart';
import 'utils/tag_style.dart';
import 'utils/tag.dart';

/// A controller for an editable text field that supports tagging behaviour.
///
/// This controller creates accurate representations of tags in the text field,
/// while also allowing for a database-friendly backend format. This format can
/// be retrieved from the controller's `textInBackendFormat` property. Do not
/// use `controller.text` directly, as the internal format typically differs.
///
/// Additional programmatical modifications to the text that this controller
/// manages should be done with caution, as it may interfere with the tagging
/// behaviour. However, the controller exposes an 'insertTaggable' method that
/// allows for the insertion of taggables at the current cursor position,
/// bypassing the regular tagging flow, e.g. for tags that are typically not
/// actively chosen by the user (e.g. the @here tag in Slack and Discord).
class TagTextEditingController<T> extends TextEditingController {
  TagTextEditingController({
    required this.searchTaggables,
    required this.buildTaggables,
    required this.toFrontendConverter,
    required this.toBackendConverter,
    this.textStyleBuilder,
    this.tagStyles = const [TagStyle()],
  }) : super() {
    addListener(taggingListeners);
    ServicesBinding.instance.keyboard.addHandler(_onKey);
  }

  @override
  void dispose() {
    ServicesBinding.instance.keyboard.removeHandler(_onKey);
    removeListener(taggingListeners);
    super.dispose();
  }

  @override
  void clear() {
    _tagBackendFormatsToTaggables = {};
    super.clear();
  }

  /// A listener that triggers all tagging-related listeners.
  void taggingListeners() {
    if (didPressDeleteKey) {
      didPressDeleteKey = false;
      _checkTagRecognizabilityController();
    }
    //_checkTagRecognizabilityController();
    _cursorController();
    final query = _checkTagQueryController();
    
    if (query != null) {
      _availableTaggablesController(query.$1, query.$2);
    }
  }

  /// Searches for taggables based on the tag prefix (e.g. '@') and query (e.g. 'Ali').
  final FutureOr<Iterable<T>> Function(String prefix, String? query)
      searchTaggables;

  /// Builds the list of taggables, if any.
  final Future<T?> Function(FutureOr<Iterable<T>> taggables) buildTaggables;

  /// Converts a taggable to a string to display in the linked text field.
  final String Function(T taggable) toFrontendConverter;

  /// Converts a taggable to a unique identifier for internal and backend use.
  final String Function(T taggable) toBackendConverter;

  /// A list of [TagStyle] styles that are supported by the controller.
  final List<TagStyle> tagStyles;

  /// A function that builds a text style for a taggable based on the tag style.
  ///
  /// If this function is not provided, the text style will be the same as the
  /// default text style of the text field.
  final TextStyle? Function(BuildContext context, String prefix, T taggable)?
      textStyleBuilder;

  /// A map that maps taggable backend formats to taggable objects.
  Map<String, T> _tagBackendFormatsToTaggables = {};

  /// The cursor position before the last change. Used for intuitive cursor movement.
  int _previousCursorPosition = -1;
  int _previousCursorPositionExtent = 0;

  /// The matches that are currently selected.
  List<T> allMatches = [];
  bool _shouldIgnoreCursorChange = false;

  /// The text formatted in backend format. Do not use `controller.text` directly.
  String get textInBackendFormat => text.replaceAll(spaceMarker, '');

  /// Returns all matching tags in the text based on the tag styles.
  Iterable<Match> _getTagMatches(String text) {
    final pattern = tagStyles
        .map((style) =>
            '${RegExp.escape(style.prefix)}$spaceMarker*(${style.regExp})')
        .join('|');
        
    return RegExp(pattern).allMatches(text);
  }

  bool didPressDeleteKey = false;

  bool _onKey(KeyEvent event) {
    final key = event.logicalKey.keyId;
    
    // delete key
    if (event is KeyDownEvent) {
      if (key == 4294967304) {
        didPressDeleteKey = true;
      }
    }
    return false;
  }

  /// Sets the initial text of the text field, converting backend strings to taggables.
  ///
  /// The `backendToTaggable` function is used to convert backend strings to taggables.
  /// It has the 'FutureOr' signature to allow for asynchronous operations.
  void setText(
    String backendText,
    FutureOr<T?> Function(String prefix, String backendString)
        backendToTaggable,
  ) async {

    final prevSelection = selection;

    final StringBuffer tmpText = StringBuffer();
    int position = 0;

    for (final Match match in _getTagMatches(backendText)) {
      final textBeforeMatch = backendText.substring(position, match.start);
      tmpText.write(textBeforeMatch);
      position = match.end;

      final tagStyle = tagStyles
          .where((style) => match.group(0)!.startsWith(style.prefix))
          .firstOrNull;

      debugPrint('tagStyle: $tagStyle');
      if (tagStyle == null) {
        tmpText.write(match.group(0));
        continue;
      }
      
      var taggable = await backendToTaggable(
          tagStyle.prefix, match.group(0)!.substring(tagStyle.prefix.length));

      if (taggable == null) {
        tmpText.write(match.group(0));
        continue;
      }
      final tag = Tag<T>(taggable: taggable, style: tagStyle);
      final tagText = tag.toModifiedString(
        toFrontendConverter,
        toBackendConverter,
        isFrontend: false,
      );

      _tagBackendFormatsToTaggables[tagText] = taggable;

      tmpText.write(tagText);
    }

    final textAfterAllTags =
        backendText.substring(position, backendText.length);
    tmpText.write(textAfterAllTags);

    text = tmpText.toString(); //.trimRight();
    
    // check if valid selection first
    if (prevSelection.baseOffset >= 0 && prevSelection.baseOffset < text.length) {
      selection = prevSelection;
    }
  }

  /// Parses a tag string (e.g. "@tag") and returns a tag object.
  Tag<T>? _parseTagString(String tagString) {
    final tagStyle = tagStyles
        .where((style) => tagString.startsWith(style.prefix))
        .firstOrNull;
    final taggable = _tagBackendFormatsToTaggables[tagString];
    if (tagStyle == null || taggable == null) return null;

    return Tag<T>(taggable: taggable, style: tagStyle);
  }

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
                color: !allMatches.contains(tag.taggable) ? tag.style.tagColor : tag.style.highlightTagColor ?? tag.style.tagColor,
                borderRadius: BorderRadius.circular(4),
            ),
            padding: tag.style.tagColor == null ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 6),
            child: Text(tagText, style: textStyle),
          ),
        ),
    );
  }

  void setPreviousCursorPosition() {
    _previousCursorPosition = selection.baseOffset;
    _previousCursorPositionExtent = selection.extentOffset;
  }

  /// A listener that ensures that the cursor is always outside of a tag.
  ///
  /// If the cursor is inside a tag, it is moved to the nearest side, unless the
  /// user moved into the tag with the arrow keys, in which case the cursor is
  /// moved to the other side.
  ///
  /// If a range is selected, any tags included in the range are selected as a whole.
  void _cursorController() {
    if (_shouldIgnoreCursorChange) {
      _shouldIgnoreCursorChange = false;


      setPreviousCursorPosition();
      return;
    }
    
    final baseOffset = selection.baseOffset;
    final extentOffset = selection.extentOffset;
    final isCollapsed = selection.isCollapsed;
    if (baseOffset == -1) return;

    final spaceMarkerBaseCount = text.substring(0, baseOffset).split(spaceMarker).length - 1;
    final spaceMarkerExtentCount = text.substring(0, extentOffset).split(spaceMarker).length - 1;
    final adjustedOffset = baseOffset + spaceMarkerBaseCount;
    final adjustedExtentOffset = extentOffset + spaceMarkerExtentCount;
    final tagMatches = _getTagMatches(text);
    final baseOffsetDifference = baseOffset - _previousCursorPosition;
    final extentOffsetDifference = extentOffset - _previousCursorPositionExtent;
    allMatches = [];

    //debugPrint('cursorController: $baseOffset ($adjustedOffset) :: $extentOffset ($adjustedExtentOffset) :: $isCollapsed');

    if (isCollapsed) {      
      final matchWithCursor = tagMatches
          .where((match) => match.start < adjustedOffset && match.end > adjustedOffset)
          .firstOrNull;
      
      // debugPrint("matchWithCursor: ${matchWithCursor?.group(0)} ${matchWithCursor?.start} ${matchWithCursor?.end}");

      if (matchWithCursor == null) {
        // The cursor is not inside a tag.
        setPreviousCursorPosition();
        return;
      }

      final matchText = matchWithCursor.group(0)!;
      final matchspaceMarkerBaseCount = text.substring(0, matchWithCursor.end).split(spaceMarker).length - 1;

      // debugPrint('diff: ${baseOffset - _previousCursorPosition}');

      final spaceBeforeTagCount = text.substring(0, matchWithCursor.start).split(spaceMarker).length - 1;

      // The cursor is inside a tag.      
      if (baseOffsetDifference.abs() == 1) {
        // The user probably moved into the tag with the arrow keys.
        // Move the cursor to the other side.
        // This is not flawless, as the user could have moved into the tag
        // by some other means, but this is the most common case.

        final setOffset = baseOffsetDifference == 1 ? (matchWithCursor.end - matchspaceMarkerBaseCount) : (matchWithCursor.start - spaceBeforeTagCount);

        // debugPrint("IN HERE ${baseOffsetDifference == 1} ${matchWithCursor.end} ${matchWithCursor.start} $matchspaceMarkerBaseCount $spaceBeforeTagCount :: $setOffset");

        _shouldIgnoreCursorChange = true;
        selection = TextSelection.collapsed(
          offset: setOffset
        );
        setPreviousCursorPosition();
        return;
      }
      // The user probably clicked into the tag.
      //Move it to the nearest side.

      final taggable = _tagBackendFormatsToTaggables[matchText];
      if (taggable == null) {
        // The tag is not recognisable. This case will be handled by the
        // _checkTagRecognizabilityController.
        return;
      }

//      debugPrint("ZZZ ${matchWithCursor.end} $matchspaceMarkerBaseCount ${matchWithCursor.start}");

      final areInsideTag = (baseOffset > matchWithCursor.start - matchspaceMarkerBaseCount) && (baseOffset < matchWithCursor.end - matchspaceMarkerBaseCount - 1);

  //    debugPrint('areInsideTag: $areInsideTag ||| $baseOffset ${matchWithCursor.end - matchspaceMarkerBaseCount - 1} ${matchWithCursor.start} --- $matchspaceMarkerBaseCount');

      _shouldIgnoreCursorChange = true;
      selection = TextSelection.collapsed(
        offset: areInsideTag
            ? matchWithCursor.end - matchspaceMarkerBaseCount
            : matchWithCursor.start - spaceBeforeTagCount,
      );
      setPreviousCursorPosition();
    } else {
      // Check if the selection covers a tag
      final matchWithExtent = tagMatches
          .where(
              (match) => match.start < adjustedExtentOffset && match.end >= adjustedExtentOffset)
          .firstOrNull;


      allMatches = tagMatches
        .where((match) => match.start < max(adjustedOffset, adjustedExtentOffset) && match.end > min(adjustedOffset, adjustedExtentOffset) + 1)
        .map((match) => _tagBackendFormatsToTaggables[match.group(0)!] as T).toList();

      final baseBeforeExtent = baseOffset < extentOffset;

      if (matchWithExtent == null) {
        // The selection does not cover a tag.
        setPreviousCursorPosition();
        return;
      }

      final spaceBeforeExtentStartTagCount = text.substring(0, matchWithExtent.start).split(spaceMarker).length - 1;
      final spaceBeforeExtentEndTagCount = text.substring(0, matchWithExtent.end).split(spaceMarker).length - 1;

      debugPrint("ALL MATCHES AND START/END: ${tagMatches.map((match) => "${match.group(0)} ${match.start} ${match.end}").toList()}");
      debugPrint("EXTENT OFFSET: $adjustedOffset $adjustedExtentOffset ${matchWithExtent?.group(0)}");   
      debugPrint("ALL MATCHES: ${allMatches.map((t) => toFrontendConverter(t)).toList()}");
      debugPrint('extentOffsetDifference: $extentOffsetDifference');
      debugPrint('matchWithExtent: ${matchWithExtent.group(0)} ${matchWithExtent.start} ${matchWithExtent.end}');
      debugPrint('baseBeforeExtent: $baseBeforeExtent $baseOffset $extentOffset');      
      debugPrint('spaceBeforeExtentTagCount: $spaceBeforeExtentStartTagCount $spaceBeforeExtentEndTagCount');

      if (extentOffsetDifference.abs() == 1) {
        int newExtentOffset;
        if (baseBeforeExtent) {
          if (extentOffsetDifference == 1) {
            // SELECTING LEFT TO RIGHT
            //debugPrint("IN HERE A ${matchWithExtent.end} $spaceBeforeExtentEndTagCount");
            newExtentOffset = matchWithExtent.end - spaceBeforeExtentEndTagCount;
          } else {
            // UNSELECTING RIGHT TO LEFT
            //debugPrint("IN HERE B ${matchWithExtent.start} $spaceMarkerBaseCount");
            newExtentOffset = matchWithExtent.start - spaceMarkerBaseCount;
          }
        } else {
          if (extentOffsetDifference == 1) {
            // UNSELECTING LEFT TO RIGHT
            //debugPrint("IN HERE C ${matchWithExtent.end} $spaceBeforeExtentEndTagCount");
            newExtentOffset = matchWithExtent.end - spaceBeforeExtentEndTagCount;
          } else {
            // SELECTING RIGHT TO LEFT
            //debugPrint("IN HERE D ${matchWithExtent.start} $spaceBeforeExtentStartTagCount");
            newExtentOffset = matchWithExtent.start - spaceBeforeExtentStartTagCount;
          }
        }
        
        _shouldIgnoreCursorChange = true; 
        selection = TextSelection(
          baseOffset: baseOffset,
          extentOffset: newExtentOffset,
        );
        setPreviousCursorPosition();
        return;
      }

      final areInsideTag = (extentOffset > matchWithExtent.start - spaceBeforeExtentEndTagCount) && (extentOffset < matchWithExtent.end - spaceBeforeExtentEndTagCount);

      debugPrint('areInsideTag: $areInsideTag ||| $extentOffset ${matchWithExtent.end - spaceBeforeExtentEndTagCount - 1} ${matchWithExtent.start} --- $spaceBeforeExtentStartTagCount $spaceBeforeExtentEndTagCount');

      _shouldIgnoreCursorChange = true;
      selection = TextSelection.collapsed(
        offset: areInsideTag
            ? matchWithExtent.end - spaceBeforeExtentEndTagCount
            : matchWithExtent.start - spaceBeforeExtentEndTagCount,
      );
    }
  }

  /// Checks if a tag can be created at the current cursor.
  ///
  /// If a tag can be created, the prefix and the prompt are returned.
  (String prefix, String prompt)? _checkTagQueryController() {
    if (!selection.isCollapsed) {
      // A range is selected, so no tag can be created
      return null;
    }
    final int currentPos = selection.baseOffset;
    if (currentPos == -1) return null;
    
    // Get the last position of a tag prefix before the cursor
    int tagStartPosition = text.substring(0, currentPos).lastIndexOf(
          RegExp(tagStyles.map((style) => style.prefix).join('|')),
        );
    if (tagStartPosition == -1) {
      return null;
    }
    final query = text.substring(tagStartPosition, currentPos);

    if (query.contains(' ')) {
      return null;
    }

    final tagStyle =
        tagStyles.where((style) => query.startsWith(style.prefix)).first;
    return (tagStyle.prefix, query.substring(tagStyle.prefix.length));
  }

  /// A listener that ensures that that tags are recognisable.
  ///
  /// If a tag is not recognisable, it is assumed to be invalid and is removed.
  /// This happens for example when the user backspaces over a tag or adds a
  /// character to the end of a tag that results in the regular expression not
  /// matching the tag anymore.
  void _checkTagRecognizabilityController() {
    debugPrint('checkTagRecognizabilityController');
    // First, check for tags that are still detected but not valid

    int lastTagIndex = -1000;
    String? lastTag;

    for (var tagStyle in tagStyles) {
      final index = text.substring(0, selection.baseOffset).lastIndexOf(tagStyle.prefix);
      if (index != -1 && index > lastTagIndex) {
        lastTagIndex = index;
        lastTag = text.substring(lastTagIndex, selection.baseOffset);
      }
    }

    if (lastTag == null) {
      return;
    }

    for (final match in _getTagMatches(text)) {
      debugPrint('match: ${match.group(0)}');
      // If the match can be parsed as a tag, it is valid
      if (_parseTagString(match.group(0)!) != null) continue;
      
      // The tag is not recognisable, so it is invalid
      // Check if the match is a superstring of a valid tag
      final originalTag = _tagBackendFormatsToTaggables.keys
          .where((key) => match.group(0)!.contains(key))
          .firstOrNull;

      debugPrint('originalTag: $originalTag');

      if (originalTag == null) {
        // The tag is not a superstring of a valid tag, nor is it a valid tag
        // It is still detected by the regular expression, so it must have been
        // trimmed at the end. Check if it is a valid tag without the last char
        final missesFinalCharacter = match.group(0)!.startsWith(lastTag!);
        // If the final character is missing, remove the tag.
        // Otherwise, the user is probably still typing the tag.

        debugPrint('missesFinalCharacter: $missesFinalCharacter');
        debugPrint('previousCursorPosition: $_previousCursorPosition');
        debugPrint('match.end: ${match.end}');
        debugPrint('lastTag: $lastTag');
        debugPrint('lastTagIndex: $lastTagIndex');

        if (missesFinalCharacter) {
          value = TextEditingValue(
            text: text.replaceRange(lastTagIndex, lastTagIndex + lastTag.length, ''),
            selection: TextSelection.collapsed(offset: lastTagIndex),
          );
        }
        continue;
      }

      final taggable = _tagBackendFormatsToTaggables[originalTag] as T;
      final tagStyle = tagStyles
          .where((style) => originalTag.startsWith(style.prefix))
          .first;
      final tagFrontendFormat = toFrontendConverter(taggable);
      final replacement = tagStyle.prefix + tagFrontendFormat;

      // Break the tag by replacing the tagValue with the tagFrontendFormat
      // This ensures the user sees the same text as before, without the tag
      value = TextEditingValue(
        text: text.replaceFirst(originalTag, replacement, match.start),
        selection: TextSelection.collapsed(
          offset:
              selection.baseOffset - originalTag.length + replacement.length,
        ),
      );
    }
    // Next, check for tags that have been broken by trimming at the start
    // For these tags, the prefix is missing its first character
    // final brokenTags = _tagBackendFormatsToTaggables.keys.expand((key) {
    //   // Create a regexp that matches occurences of 'key' without the first
    //   // character. e.g. if 'key' is '@tag', the regexp should match 'tag'
    //   // but not '@tag'.
    //   final pattern = '(?<!${key.substring(0, 1)})${key.substring(1)}';
    //   return RegExp(pattern).allMatches(text);
    // });
    // for (final brokenTag in brokenTags) {
    //   // Remove the entire tag. The selection can remain the same.
    //   value = TextEditingValue(
    //     text: text.replaceRange(brokenTag.start, brokenTag.end, ''),
    //     selection: TextSelection.collapsed(offset: brokenTag.start),
    //   );
    // }
  }

  /// A listener that searches for taggables based on the current tag prompt.
  ///
  /// If taggable options are found, the user is prompted to select one.
  void _availableTaggablesController(String prefix, String prompt) async {
    final taggables = searchTaggables(prefix, prompt);
    buildTaggables(taggables).then((taggable) {
      if (taggable == null) return;
      insertTaggable(prefix, taggable, prompt.length + prefix.length);
    });
  }

  /// Inserts a [taggable] into the text field at the current cursor position.
  ///
  /// Insertion typically replaces any tag prompt with the taggable. The number
  /// of characters to replace is given by [charactersToReplace].
  void insertTaggable(String prefix, T taggable, int charactersToReplace, {bool addSpace = false}) {
    final tagStyle = tagStyles.where((style) => prefix == style.prefix).first;
    final tag = Tag<T>(taggable: taggable, style: tagStyle);
    final tagText = tag.toModifiedString(
      toFrontendConverter,
      toBackendConverter,
      isFrontend: false,
    ) + (addSpace ? " " : '');

    _tagBackendFormatsToTaggables[tagText] = taggable;

    final end = selection.baseOffset;
    final start = end - charactersToReplace;

    value = TextEditingValue(
      text: text.replaceRange(start, end, tagText),
      selection: TextSelection.collapsed(offset: start + tagText.length),
    );
  }
}
