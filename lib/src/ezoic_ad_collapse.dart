/// Shared collapse-on-no-fill state logic for the platform-view ad widgets.
library;

/// Decides whether an ad widget should render collapsed after the native SDK
/// reported a size change of [height] (in dp/points).
///
/// The native SDKs report `0x0` when a load ends in a terminal no-fill while
/// nothing is displayed, and the creative size after a successful load. The
/// widget collapses only when the host opted in via [collapseOnNoFill] and the
/// reported height is zero; any non-zero height expands (or keeps) the view.
bool shouldCollapse({required bool collapseOnNoFill, required double height}) {
  return collapseOnNoFill && height <= 0;
}

/// Parses the `{width, height}` payload of an `onSizeChange` platform-channel
/// call into doubles, tolerating integer dp values (Android) and missing keys.
({double width, double height}) parseSizeChangeArguments(Object? arguments) {
  final args = (arguments as Map?)?.cast<String, dynamic>() ?? const {};
  return (
    width: (args['width'] as num?)?.toDouble() ?? 0.0,
    height: (args['height'] as num?)?.toDouble() ?? 0.0,
  );
}
