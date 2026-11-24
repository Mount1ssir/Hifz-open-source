import 'package:material_ui/material_ui.dart';

/// Collapses controls without recreating the page or changing its typography.
class ReaderControls extends StatelessWidget {
  const ReaderControls({
    super.key,
    required this.visible,
    required this.child,
    this.reserveSpace = false,
  });
  final bool visible;
  final Widget child;
  final bool reserveSpace;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 1, end: visible ? 1 : 0),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200),
    curve: Curves.easeInOut,
    child: ExcludeSemantics(
      excluding: !visible,
      child: IgnorePointer(ignoring: !visible, child: child),
    ),
    builder: (context, value, child) => ClipRect(
      child: Align(
        heightFactor: reserveSpace ? 1 : value,
        child: Opacity(opacity: value, child: child),
      ),
    ),
  );
}
