/// A class that represents a distinct way of styling tags.
class TagStyle {
  const TagStyle({
    this.prefix = '@',
    this.regExp = r'[a-zA-Z0-9]+',
    this.showPrefix = true,
  });

  /// The prefix that identifies the tag, e.g. '@' in '@tag'. Defaults to '@'.
  ///
  /// The prefix may be a single character or a sequence of characters.
  final String prefix;

  /// The regular expression used for parsing the backend representation of the tag.
  ///
  /// Typically, tags are to be stored using a unique identifier, e.g. a user ID,
  /// that tend to be alphanumeric. The default regular expression is '[a-zA-Z0-9]+',
  /// If the exact length of the identifier is known, it may be specified here.
  /// The benefit of adding the exact length is that it would allow for writing
  /// alphanumeric characters directly after the tag without breaking the tag.
  ///
  /// The regular expression used for this tag style should be the same as what
  /// would be used in any other parsing operation done on the backend, e.g. for
  /// sending tagged objects a notification by parsing the backend string on the
  /// server.
  ///
  /// The regular expression should not contain the prefix.
  final String regExp;

  /// Whether to show the prefix in the frontend.
  final bool showPrefix;
}
