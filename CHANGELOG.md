## 1.1.1

* Fixed a bug where the text after the last tag would not be set correctly when using `setText` on a `TagTextEditingController` object.
* Added a screenshot to the pubspec.yaml file.
* The deprecated `textStyle` parameter of the `TagStyle` class has been removed.

## 1.1.0

* Added the `textStyleBuilder` parameter to the `TagTextEditingController` constructor for determining the style of tags in the TextField, in favor of the `textStyle` parameter of the `TagStyle` class, which has been deprecated. The builder allows you to use the TextField's `BuildContext` when initializing the `TagTextEditingController` object in the `initState` method of a StatefulWidget, such that you can access inherited styles such as `Theme.of(context).textTheme`.

## 1.0.1

* Fixed a formatting issue

## 1.0.0

* First stable release. Please refer to the README, the API documentation, and the examples for more information.
* Added support for tagging entities that have the same frontend format
* Added fine-grained control over the backend format of tags. This allows for more flexibility, including no longer requiring whitespace on either side of a tag.
* Added the `convertTagTextToInlineSpans` function, which converts tag text to inline spans with some customizability.

## 0.0.4

* Fixed a formatting issue

## 0.0.3

* Fixed a formatting issue

## 0.0.2

* Minor fixes to publishing issues

## 0.0.1

* Initial release
