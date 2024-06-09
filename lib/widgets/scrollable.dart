part of '../sliding_drawers.dart';

class SlidingDrawersScrollable extends StatefulWidget {
  const SlidingDrawersScrollable({
    super.key,
    this.fillViewport = false,
    this.padding,
    this.primary,
    this.controller,
    this.dragStartBehavior = DragStartBehavior.start,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.child,
  });

  SlidingDrawersScrollable.listView({
    super.key,
    this.fillViewport = false,
    this.controller,
    this.padding,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.primary,
    required int itemCount,
    required Widget? Function(BuildContext, int) itemBuilder,
    int? Function(Key)? findChildIndexCallback,
    Widget Function(BuildContext, int)? separatorBuilder,
  }) : child = ListView.builder(
          key: key,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          clipBehavior: Clip.none,
          padding: EdgeInsets.zero,
          itemCount: (separatorBuilder == null
              ? itemCount
              : (math.max(0, 2 * itemCount - 1))),
          findChildIndexCallback: separatorBuilder == null
              ? findChildIndexCallback
              : findChildIndexCallback == null
                  ? null
                  : (key) {
                      var index = findChildIndexCallback(key);
                      return index == null ? null : (index / 2).floor();
                    },
          itemBuilder: separatorBuilder == null
              ? itemBuilder
              : (context, index) {
                  final itemIndex = (index / 2).floor();
                  return index.isEven
                      ? itemBuilder(context, itemIndex)
                      : separatorBuilder(context, itemIndex);
                },
        );

  final bool fillViewport;
  final EdgeInsetsGeometry? padding;
  final bool? primary;
  final ScrollController? controller;
  final DragStartBehavior dragStartBehavior;
  final Clip clipBehavior;
  final String? restorationId;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final Widget? child;

  @override
  State<SlidingDrawersScrollable> createState() =>
      _SlidingDrawersScrollableState();
}

class _SlidingDrawersScrollableState extends State<SlidingDrawersScrollable>
    with WidgetsBindingObserver {
  _SlidingDrawersAreaState? _scope;
  _SlidingDrawersAreaState get scope {
    assert(_scope != null);
    return _scope!;
  }

  ScrollController? _localController;
  ScrollController get controller => widget.controller ?? _localController!;

  late final DebouncedAction _scrollEndAction = DebouncedAction(
    duration: const Duration(milliseconds: 200),
    action: () {
      _scope?.top.snapDrawers(() => _scrollEndAction.debounced);
      _scope?.bottom.snapDrawers(() => _scrollEndAction.debounced);
    },
  );

  @override
  void initState() {
    super.initState();

    if (widget.controller == null) {
      _localController = ScrollController();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final scope = _SlidingDrawersScope.of(context);
    if (_scope != scope) {
      _scope = scope..resetDrawers();
      _notifyScope();
    }
  }

  void _notifyScope() {
    final position =
        controller.positions.firstWhereOrNull((p) => p.axis == Axis.vertical);
    if (position != null) {
      scope.handleScrollUpdate(0, position.pixels, position.maxScrollExtent);
    }
  }

  @override
  void didUpdateWidget(covariant SlidingDrawersScrollable oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      if (oldWidget.controller == null) {
        _localController!.dispose();
        _localController = null;
      } else {
        //_unsyncController(oldWidget.controller!);
      }

      if (widget.controller == null) {
        _localController = ScrollController();
      } else {
        //_syncController(widget.controller!);
      }

      _notifyScope();
    }
  }

  @override
  void deactivate() {
    _scope?.resetDrawers();
    super.deactivate();
  }

  @override
  void dispose() {
    super.dispose();
    _localController?.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;

    if (notification is ScrollEndNotification) {
      _scrollEndAction.invoke();
    } else if (notification is OverscrollNotification) {
      //Log.i("-- OverscrollNotification");
    } else if (notification is ScrollUpdateNotification) {
      scope.handleScrollUpdate(
        notification.scrollDelta ?? 0,
        notification.metrics.pixels,
        notification.metrics.maxScrollExtent,
      );
      return true;
    }

    return false;
  }

  Widget _buildScrollable(
      BuildContext context, EdgeInsetsGeometry padding, Widget? child) {
    return ValueListenableBuilder(
      valueListenable: scope.scrollableInsetsNotifier,
      builder: (context, scrollableInsets, child) {
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          primary: widget.primary,
          padding: padding.add(scrollableInsets),
          controller: controller,
          physics: const ClampingScrollPhysics(),
          dragStartBehavior: widget.dragStartBehavior,
          clipBehavior: widget.clipBehavior,
          restorationId: widget.restorationId,
          keyboardDismissBehavior: widget.keyboardDismissBehavior,
          child: child,
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget? viewport = widget.child;

    final padding = widget.padding ?? EdgeInsets.zero;

    if (_kDrawDebugBounds) {
      // Viewport bounds
      viewport = DebugAreaBounds(child: viewport);
    }

    Widget scrollable = widget.fillViewport
        ? LayoutBuilder(builder: (context, constraints) {
            final scrollableHeight = constraints.maxHeight;
            return _buildScrollable(
              context,
              padding,
              ValueListenableBuilder(
                valueListenable: scope.fillViewportExtendsNotifier,
                builder: (context, fillViewportExtends, child) {
                  final viewportHeight =
                      scrollableHeight - padding.vertical + fillViewportExtends;

                  //Log.i("scrollable: ${scrollableHeight.toStringAsFixed(2)}");
                  //Log.i("viewport: ${viewportHeight.toStringAsFixed(2)}");

                  return ConstrainedBox(
                    constraints: BoxConstraints(
                        minHeight: viewportHeight, minWidth: double.infinity),
                    child: child,
                  );
                },
                child: viewport,
              ),
            );
          })
        : _buildScrollable(context, padding, viewport);

    if (_kDrawDebugBounds) {
      // Scrollable bounds
      scrollable = DebugAreaBounds(
        color: Colors.green,
        child: scrollable,
      );
    }

    return NotificationListener(
      onNotification: _handleScrollNotification,
      child: scrollable,
    );
  }
}
