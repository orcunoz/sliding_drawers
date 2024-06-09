import 'package:flutter/material.dart';

class DebugAreaBounds extends StatelessWidget {
  const DebugAreaBounds({
    super.key,
    this.color = Colors.blue,
    this.drawOver = false,
    this.child,
  });

  final Color color;
  final bool drawOver;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      position: drawOver
          ? DecorationPosition.foreground
          : DecorationPosition.background,
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        border: Border.all(width: 2, color: color),
      ),
      child: child,
    );
  }
}
