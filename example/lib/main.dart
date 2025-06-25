import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_taggable/flutter_taggable.dart';

class Taggable {
  const Taggable({required this.id, required this.name, required this.icon});

  final String id;
  final String name;
  final IconData icon;
}

class User extends Taggable {
  const User(
      {required super.id, required super.name, super.icon = Icons.person});
}

class Topic extends Taggable {
  const Topic(
      {required super.id, required super.name, super.icon = Icons.topic});
}

/// A list of users to search from.
const users = <User>[
  User(id: 'ja', name: 'Jason'),
  User(id: 'eva_rostova', name: 'Commander Eva Rostova'),
  User(id: 'craft_space_interior', name: 'Craft space Interior'),
  User(id: 'space', name: 'Space', icon: Icons.person_outline),
  User(id: 'baby_got_back', name: 'Baby got back'),
  User(id: 'bobUniqueId', name: 'Bob'),
  User(id: 'charlie', name: 'Charlie'),
  User(id: 'carolUniqueId', name: 'Carol'),
  User(id: 'hawkingUniqueId', name: 'Stephen Hawking'),
];

/// A list of topics to search from.
const topics = <Topic>[
  Topic(id: 'myDartId', name: 'Dart'),
  Topic(id: 'myFlutterId', name: 'Flutter'),
  Topic(id: 'myPubId', name: 'Pub'),
];

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: HomePage()),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// The [LayerLink] is used to link the [CompositedTransformTarget] and
  /// [CompositedTransformFollower] widgets required to show the overlay.
  final _layerLink = LayerLink();

  /// The [_formKey] is used to get the [RenderBox] of the [Form] widget to
  /// position the overlay.
  final _formKey = GlobalKey<FormState>();

  /// The [_focusNode] is used to focus the [TextField] when the overlay is
  /// closed.
  late FocusNode _focusNode;

  /// A list of comments made using the [TagTextEditingController].
  final List<List<InlineSpan>> comments = [];

  /// The [TagTextEditingController] is used to control the [TextField] and
  /// handle the tagging logic.
  late final TagTextEditingController _controller;

  /// The [_overlayEntry] is used to show the overlay with the list of
  /// taggables.
  OverlayEntry? _overlayEntry;

  /// The [backendFormat] is used to display the backend format of the text
  String backendFormat = '';

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    // Initialize the [TagTextEditingController] with the required parameters.
    _controller = TagTextEditingController<Taggable>(
      searchTaggables: searchTaggables,
      buildTaggables: buildTaggables,
      toFrontendConverter: (taggable) => taggable.name,
      toBackendConverter: (taggable) => taggable.id,
      textStyleBuilder: textStyleBuilder,
      tagStyles: [
        TagStyle(
            prefix: '@',
            showPrefix: false,
            tagColor: Colors.blue,
            highlightTagColor: Colors.red,
            onTapped: (taggable) => debugPrint('Tapped ${taggable.name}'))
      ],
    );

    // Add a listener to update the [backendFormat] when the text changes.
    _controller.addListener(
        () => setState(() => backendFormat = _controller.textInBackendFormat));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  TextStyle? textStyleBuilder(
      BuildContext context, String prefix, Taggable taggable) {
    // if (taggable.id == 'hawkingUniqueId') {
    //   return const TextStyle(
    //     color: Colors.red,
    //     decoration: TextDecoration.underline,
    //     fontWeight: FontWeight.bold,
    //   );
    // }
    return switch (prefix) {
      '@' => const TextStyle(
          color: Colors.white, height: 1.6, fontWeight: FontWeight.bold),
      '#' => const TextStyle(
          color: Colors.white, height: 1.6, fontWeight: FontWeight.bold),
      _ => null,
    };
  }

  /// This method is used to build the [InlineSpan]s from the backend format.
  FutureOr<List<InlineSpan>> _buildTextSpans(
    String backendFormat,
    BuildContext context,
  ) async {
    return convertTagTextToInlineSpans<Taggable>(
      backendFormat,
      tagStyles: _controller.tagStyles,
      backendToTaggable: backendToTaggable,
      taggableToInlineSpan: (taggable, tagStyle) {
        return TextSpan(
          text: '${tagStyle.prefix}${taggable.name}',
          style: textStyleBuilder(context, tagStyle.prefix, taggable),
          recognizer: TapGestureRecognizer()
            ..onTap = () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Tapped ${taggable.name} with id ${taggable.id}',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                ),
        );
      },
    );
  }

  /// Shows the overlay with the list of taggables.
  Future<Taggable?> buildTaggables(
      FutureOr<Iterable<Taggable>> taggables) async {
    final availableTaggables = await taggables;

    // We use a [Completer] to return the selected taggable from the overlay.
    // This is because overlays do not return values directly.
    Completer<Taggable?> completer = Completer();

    // Remove the existing overlay if it exists.
    _overlayEntry?.remove();
    if (availableTaggables.isEmpty) {
      // If there are no taggables to show, we return null.
      _overlayEntry = null;
      completer.complete(null);
    } else {
      _overlayEntry = OverlayEntry(builder: (context) {
        // The following few lines are used to position the overlay above the
        // [TextField]. It moves along if the [TextField] moves.
        final renderBox =
            _formKey.currentContext!.findRenderObject() as RenderBox;
        return Positioned(
          width: renderBox.size.width,
          bottom: renderBox.size.height + 8,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.bottomLeft,
            child: Material(
              child: ListView(
                shrinkWrap: true,
                children: availableTaggables.map((taggable) {
                  // We show the list of taggables in a [ListView].
                  return ListTile(
                    leading: Icon(taggable.icon),
                    title: Text(taggable.name),
                    tileColor: Theme.of(context).colorScheme.primaryContainer,
                    onTap: () {
                      // When a taggable is selected, remove the overlay
                      _overlayEntry?.remove();
                      _overlayEntry = null;
                      // and complete the Completer with the selected taggable.
                      completer.complete(taggable);
                      // Focus the [TextField] to continue typing.
                      // Do this after completing the Completer to avoid
                      // interfering with the logic of adding the taggable.
                      _focusNode.requestFocus();
                    },
                  );
                }).toList(),
              ),
            ),
          ),
        );
      });
      if (mounted) {
        Overlay.of(context).insert(_overlayEntry!);
      }
    }
    return completer.future;
  }

  /// This method searches for taggables based on the tag prefix and tag name.
  ///
  /// You can specify different behaviour based on the tag prefix.
  Future<Iterable<Taggable>> searchTaggables(
      String tagPrefix, String? tagName) async {
    if (tagName == null || tagName.isEmpty) {
      return [];
    }
    return switch (tagPrefix) {
      '@' => users
          .where((user) =>
              user.name.toLowerCase().startsWith(tagName.toLowerCase()))
          .toList(),
      '#' => topics
          .where((topic) =>
              topic.name.toLowerCase().startsWith(tagName.toLowerCase()))
          .toList(),
      'all:' => [...users, ...topics].where((taggable) =>
          taggable.name.toLowerCase().startsWith(tagName.toLowerCase())),
      _ => [],
    };
  }

  /// This method converts the backend format to the taggable object.
  FutureOr<Taggable?> backendToTaggable(String prefix, String id) {
    return switch (prefix) {
      '@' => users.where((user) => user.id == id).firstOrNull,
      '#' => topics.where((topic) => topic.id == id).firstOrNull,
      'all:' => [...users, ...topics]
          .where((taggable) => taggable.id == id)
          .firstOrNull,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Build a list of comments made using the [TagTextEditingController].
    // as well as a [TextField] to add new comments.

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...comments.map((comment) {
                return Card(
                  margin: const EdgeInsets.all(4),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text.rich(
                      TextSpan(
                        children: comment,
                      ),
                    ),
                  ),
                );
              }),
              Form(
                key: _formKey,
                child: CompositedTransformTarget(
                  link: _layerLink,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 4,
                    style: const TextStyle(height: 1.8),
                    decoration: InputDecoration(
                      hintText: 'Type @ to tag a user',
                      helperText: 'Backend format: $backendFormat',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: () async {
                          final textSpans =
                              await _buildTextSpans(_controller.text, context);
                          setState(() {
                            comments.add(textSpans);
                            _controller.clear();
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  // This is an example of setting the initial text.
                  _controller.setText(
                    "Hi @bobUniqueId, you are in @space right now.",
                    //"A bright image appears due to Europa's reflected light. @ja and @eva_rostova are in the @spacecraft_interior_testing. They look at the picture.",
                    backendToTaggable,
                  );
                  _focusNode.requestFocus();
                },
                child: const Text('Set initial text'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
