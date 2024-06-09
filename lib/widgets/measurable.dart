import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../utils/scheduler_callbacks.dart';

class MeasurableBuilder extends StatefulWidget {
  const MeasurableBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, Size? size) builder;

  @override
  State<MeasurableBuilder> createState() => _MeasurableBuilderState();
}

class _MeasurableBuilderState extends State<MeasurableBuilder> {
  Size? size;

  @override
  Widget build(BuildContext context) {
    return Measurable(
      computedSize: size,
      onLayout: (size) {
        if (this.size?.width != size.width ||
            this.size?.height != size.height) {
          LnSchedulerCallbacks.endOfFrame(() => setState(() {
                this.size = size;
              }));
        }
      },
      child: widget.builder(context, size),
    );
  }
}

class Measurable extends SingleChildRenderObjectWidget {
  const Measurable({
    super.key,
    this.computedSize,
    required this.onLayout,
    required super.child,
  });

  final Size? computedSize;
  final ValueChanged<Size> onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _MeasurableRenderObject((size) {
        if (size != computedSize) onLayout(size);
      });
}

class _MeasurableRenderObject extends RenderProxyBox {
  _MeasurableRenderObject(this.onLayout);

  final ValueChanged<Size> onLayout;

  @override
  void performLayout() {
    super.performLayout();
    onLayout(size);
  }
}
