part of '../sliding_drawers.dart';

const kSlidingDrawersAnimationDuration = Duration(milliseconds: 300);
const kSlidingDrawersAnimationCurve = Curves.easeInOut;

const int _maxInt =
    (double.infinity is int) ? double.infinity as int : ~_minInt;
const int _minInt =
    (double.infinity is int) ? -double.infinity as int : (-1 << 63);

typedef DrawerFrameBuilder = Widget Function(
    BuildContext context, SlidingDrawerTranslation position, Widget child);

enum DrawerOnScrollBehavior {
  slide,
  stayBelow,
}

class LimitedRange {
  const LimitedRange({this.min, this.max})
      : assert(min == null || max == null || min <= max,
            "min <= max': is not true ($min <= $max)");

  const LimitedRange.constant(num value) : this(min: value, max: value);

  final num? min;
  final num? max;

  @override
  String toString() => "$min < limits < $max";

  LimitedRange operator *(num operand) => LimitedRange(
        min: min == null ? null : min! * operand,
        max: max == null ? null : max! * operand,
      );

  LimitedRange operator +(LimitedRange operand) => LimitedRange(
        min: (min ?? 0) + (operand.min ?? 0),
        max: (max ?? 0) + (operand.max ?? 0),
      );

  LimitedRange operator -(LimitedRange operand) => LimitedRange(
        min: (min ?? 0) - (operand.min ?? 0),
        max: (max ?? 0) - (operand.max ?? 0),
      );

  static LimitedRange? lerp(LimitedRange? a, LimitedRange? b, double t) {
    if (t <= 0 || t >= 1 || a == null || b == null) {
      return t >= .5 ? b : a;
    } else {
      return LimitedRange(
        min: a.min == null || b.min == null
            ? (t >= .5 ? b.min : a.min)
            : lerpDouble(a.min, b.min, t)!,
        max: a.max == null || b.max == null
            ? (t >= .5 ? b.max : a.max)
            : lerpDouble(a.max, b.max, t)!,
      );
    }
  }
}

class LimitedRangeTween extends Tween<LimitedRange> {
  LimitedRangeTween({super.begin, super.end});

  @override
  LimitedRange lerp(double t) => LimitedRange.lerp(begin, end, t)!;
}

class ReverseSlidingDrawer extends SlidingDrawer {
  const ReverseSlidingDrawer({
    super.key,
    required this.reverseOf,
    super.frameBuilder,
    required super.child,
  }) : super._reverse();

  final GlobalKey<SlidingDrawerState> reverseOf;

  @override
  State<SlidingDrawer> createState() => _ReverseSlidingDrawerState();
}

class SlidingDrawer extends StatefulWidget {
  const SlidingDrawer.pinned({
    super.key,
    this.slideLimits,
    this.heightLimits,
    required this.slideDirection,
    this.onScrollableBounds = false,
    this.behavior = DrawerOnScrollBehavior.slide,
    this.frameBuilder,
    this.child,
  })  : pinned = true,
        snap = false,
        slidePriority = _maxInt;

  const SlidingDrawer({
    super.key,
    this.snap = false,
    this.slideLimits,
    this.heightLimits,
    this.slidePriority = 1,
    required this.slideDirection,
    this.onScrollableBounds = false,
    this.behavior = DrawerOnScrollBehavior.slide,
    this.frameBuilder,
    this.child,
  })  : pinned = false,
        assert(slidePriority < _maxInt);

  const SlidingDrawer._reverse({
    super.key,
    this.behavior = DrawerOnScrollBehavior.slide,
    this.frameBuilder,
    this.child,
  })  : snap = false,
        onScrollableBounds = false,
        slideDirection = null,
        pinned = false,
        heightLimits = null,
        slideLimits = null,
        slidePriority = 1;

  final bool onScrollableBounds;
  final bool snap;
  final bool pinned;
  final LimitedRange? slideLimits;
  final LimitedRange? heightLimits;
  final int slidePriority;
  final DrawerOnScrollBehavior behavior;
  final VerticalDirection? slideDirection;
  final DrawerFrameBuilder? frameBuilder;
  final Widget? child;

  @override
  State<SlidingDrawer> createState() => _SlidingDrawerState();
}

abstract class SlidingDrawerTranslation {
  SlidingDrawerBounds? get bounds;
  double get slideAmount;
  double get slideableLength;
  double get minHeight;
  double get maxHeight;
  double get transition;
  double get reverseTransition;
}

abstract class SlidingDrawerState extends State<SlidingDrawer>
    with AfterLayout
    implements SlidingDrawerActions, SlidingDrawerTranslation {
  double? relativeOffset;

  bool get isReverse => this is _ReverseSlidingDrawerState;

  int get priority => widget.slidePriority;
  bool get onScrollableBounds => widget.onScrollableBounds;

  final _visibleHeightNotifier = ValueNotifier<double>(0);
  ValueListenable<double> get visibleHeightListenable => _visibleHeightNotifier;
  double get visibleHeight => _visibleHeightNotifier.value;

  final _boundsNotifier = ValueNotifier<SlidingDrawerBounds?>(null);
  ValueListenable<SlidingDrawerBounds?> get boundsListenable => _boundsNotifier;

  @override
  SlidingDrawerBounds? get bounds => _boundsNotifier.value;

  late final Listenable positionListenable = Listenable.merge([
    _visibleHeightNotifier,
    _boundsNotifier,
  ]);

  double? _pinnedOffset;
  set pinnedOffset(double value) {
    _pinnedOffset = value;
  }

  double get pinnedOffset => _pinnedOffset ?? .0;

  Size? _measuredSize;
  SlidingDrawers? _area;

  VerticalDirection? slideDirection;

  @override
  double get slideAmount =>
      bounds == null ? 0 : bounds!.maxHeight - visibleHeight;

  @override
  double get slideableLength => bounds?.maxSlide ?? 0;

  @override
  double get minHeight => bounds?.minHeight ?? .0;

  @override
  double get maxHeight => bounds?.maxHeight ?? .0;

  @override
  double get transition {
    if (bounds != null && slideableLength > 0) {
      return (slideAmount / slideableLength).clamp(0, 1);
    }
    return 0;
  }

  @override
  double get reverseTransition {
    return 1 - transition;
  }

  SlidingDrawerBounds? _calculateBounds(double? measuredHeight);

  void setSlidePosition({double? slide, double? height, double? transition});

  void _recalculateBounds() {
    final previousSlide = slideAmount;

    _boundsNotifier.value = _calculateBounds(_measuredSize?.height);
    setSlidePosition(slide: previousSlide);
  }

  double handleScroll(double change) {
    double sign = switch (slideDirection!) {
      VerticalDirection.up => 1.0,
      VerticalDirection.down => -1.0,
    };

    final previousSlide = slideAmount;
    double? newVisibleHeight;

    if (!isReverse) {
      final double newSlide = previousSlide + change * sign;
      newVisibleHeight = bounds?.normalizedHeightOf(slide: newSlide);
    }

    setSlidePosition(height: newVisibleHeight);

    return (slideAmount - previousSlide) * sign;
  }

  void _refreshRegistration({bool force = false}) {
    final area = SlidingDrawers.of(context);
    slideDirection = isReverse
        ? ((widget as ReverseSlidingDrawer).reverseOf.currentWidget
                as SlidingDrawer?)
            ?.slideDirection
        : area.directionOf(widget) ?? widget.slideDirection;

    assert(slideDirection != null,
        "SlidingDrawer slide direction couldn't resolve");

    if (area != _area || force) {
      _area?.unregister(this);
      _area = area..register(this, slideDirection!);
    }
  }

  @override
  void afterLayout() {
    super.afterLayout();

    _recalculateBounds();
  }

  @override
  void didUpdateWidget(SlidingDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.onScrollableBounds != oldWidget.onScrollableBounds ||
        widget.slideDirection != oldWidget.slideDirection ||
        widget.slidePriority != oldWidget.slidePriority) {
      _refreshRegistration(force: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (this is! _ReverseSlidingDrawerState ||
        (this as _ReverseSlidingDrawerState).reverseController != null) {
      _refreshRegistration();
    }
  }

  @override
  void dispose() {
    _boundsNotifier.dispose();
    _visibleHeightNotifier.dispose();

    _area?.unregister(this);
    _area = null;
    super.dispose();
  }

  Widget _buildChild() {
    bool topDrawer = slideDirection == VerticalDirection.up;
    bool slideBehavior = widget.behavior == DrawerOnScrollBehavior.slide;

    return UnconstrainedBox(
      alignment: topDrawer ^ !slideBehavior
          ? Alignment.bottomCenter
          : Alignment.topCenter,
      clipBehavior: Clip.hardEdge,
      constrainedAxis: Axis.horizontal,
      child: Measurable(
        computedSize: _measuredSize,
        onLayout: (size) {
          bool needUpdate = size.height != _measuredSize?.height;
          _measuredSize = size;
          if (needUpdate) {
            LnSchedulerCallbacks.endOfFrame(_recalculateBounds);
          }
        },
        child: widget.child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: ListenableBuilder(
        listenable: positionListenable,
        builder: (context, child) {
          return SizedBox(
            height: visibleHeight,
            child: widget.frameBuilder?.call(context, this, child!) ?? child!,
          );
        },
        child: _buildChild(),
      ),
    );
  }

  @override
  void close({
    Duration? duration = kSlidingDrawersAnimationDuration,
    Curve? curve = kSlidingDrawersAnimationCurve,
  }) {
    slideTo(double.infinity, duration: duration, curve: curve);
  }

  @override
  void open({
    Duration? duration = kSlidingDrawersAnimationDuration,
    Curve? curve = kSlidingDrawersAnimationCurve,
  }) {
    slideTo(0, duration: duration, curve: curve);
  }
}

class _ReverseSlidingDrawerState extends SlidingDrawerState {
  @override
  ReverseSlidingDrawer get widget => super.widget as ReverseSlidingDrawer;
  SlidingDrawerState? get reverseController => widget.reverseOf.currentState;

  double? _convertVisibleHeightToReverse(double? height) =>
      height == null || bounds == null || reverseController?.bounds == null
          ? null
          : reverseController!.maxHeight - (height - bounds!.minHeight);

  @override
  void slideTo(double value, {Duration? duration, Curve? curve}) {
    reverseController?.slideTo(
      slideableLength - value,
      duration: duration,
      curve: curve,
    );
  }

  void _syncReverseDrawer(SlidingDrawerState reverseDrawer) {
    reverseDrawer.positionListenable.addListener(_handleReverseSlide);
    _recalculateBounds();
  }

  void _unsyncReverseDrawer(SlidingDrawerState reverseDrawer) {
    reverseDrawer.positionListenable.addListener(_handleReverseSlide);
    _recalculateBounds();
  }

  @override
  void setSlidePosition({double? slide, double? height, double? transition}) {
    final visibleHeight = bounds?.normalizedHeightOf(
      slide: slide,
      height: height,
      transition: transition,
    );

    final reverseHeight = _convertVisibleHeightToReverse(visibleHeight);

    if (reverseHeight != null) {
      reverseController?.setSlidePosition(height: reverseHeight);
    }
  }

  void _handleReverseSlide() {
    setSlidePosition(
      height: bounds?.normalizedHeightOf(
          height: bounds!.minHeight + (reverseController?.slideAmount ?? 0)),
    );
  }

  @override
  SlidingDrawerBounds? _calculateBounds(double? measuredHeight) {
    if (reverseController?.bounds == null) return null;
    final reverseBounds = reverseController!.bounds!;
    measuredHeight ??= reverseBounds.maxHeight;

    final additionalHeight =
        math.max(measuredHeight - reverseBounds.maxHeight, 0);
    return SlidingDrawerBounds(
      minHeight: reverseBounds.minHeight + additionalHeight,
      maxHeight: reverseBounds.maxHeight + additionalHeight,
      measuredHeight: reverseBounds.maxHeight + additionalHeight,
    );
  }

  @override
  void afterLayout() {
    super.afterLayout();

    _refreshRegistration();
    _syncReverseDrawer(reverseController!);
  }

  @override
  void didUpdateWidget(covariant ReverseSlidingDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reverseOf != oldWidget.reverseOf) {
      _unsyncReverseDrawer(oldWidget.reverseOf.currentState!);
      _syncReverseDrawer(widget.reverseOf.currentState!);
    }
  }

  @override
  void dispose() {
    if (reverseController != null) _unsyncReverseDrawer(reverseController!);
    super.dispose();
  }
}

class _SlidingDrawerState extends SlidingDrawerState
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  Animation<double>? _slideAnimation;

  @override
  double handleScroll(double change) {
    _cancelAnimation();
    return super.handleScroll(change);
  }

  void _cancelAnimation() {
    _slideAnimation?.removeListener(_handleAnimationUpdate);
  }

  @override
  void slideTo(double value, {Duration? duration, Curve? curve}) {
    _cancelAnimation();

    if (duration == null) {
      setSlidePosition(slide: value);
    } else {
      Animation<double> parent = _animationController;
      if (curve != null) {
        parent = CurvedAnimation(parent: parent, curve: curve);
      }

      _slideAnimation = Tween<double>(
        begin: slideAmount,
        end: value.clamp(0, slideableLength),
      ).animate(parent)
        ..addListener(_handleAnimationUpdate);

      _animationController
        ..duration = duration
        ..forward(from: 0);
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      value: 0,
    );
  }

  @override
  void dispose() {
    _slideAnimation?.removeListener(_handleAnimationUpdate);
    _animationController.dispose();
    super.dispose();
  }

  @override
  void setSlidePosition({double? slide, double? height, double? transition}) {
    final newVisibleHeight = bounds?.normalizedHeightOf(
      slide: slide,
      height: height,
      transition: transition,
    );

    if (newVisibleHeight != visibleHeight) {
      _visibleHeightNotifier.value = newVisibleHeight ?? 0;
    }
  }

  void _handleAnimationUpdate() {
    if (_slideAnimation != null) {
      setSlidePosition(slide: _slideAnimation!.value);
    }
  }

  @override
  void didUpdateWidget(covariant SlidingDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.slideLimits != oldWidget.slideLimits ||
        widget.heightLimits != oldWidget.heightLimits) {
      LnSchedulerCallbacks.endOfFrame(_recalculateBounds);
    }
  }

  @override
  SlidingDrawerBounds? _calculateBounds(double? measuredHeight) {
    LimitedRange? heightLimits = widget.heightLimits;
    LimitedRange? slideLimits = widget.slideLimits;

    double? minHeight = heightLimits?.min?.toDouble();
    double? maxHeight = heightLimits?.max?.toDouble();

    if (slideLimits != null && measuredHeight != null) {
      if (slideLimits.max != null) {
        minHeight = math.max(
          minHeight ?? 0,
          measuredHeight - slideLimits.max!,
        );
      }
      if (slideLimits.min != null) {
        maxHeight = math.min(
          maxHeight ?? double.infinity,
          measuredHeight - slideLimits.min!,
        );
      }
    }

    minHeight ??= 0;
    maxHeight ??= measuredHeight != null
        ? math.max(minHeight, measuredHeight)
        : minHeight;

    return SlidingDrawerBounds(
      minHeight: minHeight,
      maxHeight: maxHeight,
      measuredHeight: measuredHeight,
    );
  }
}

abstract class SlidingDrawerActions {
  void open({Duration? duration = kSlidingDrawersAnimationDuration});

  void close({Duration? duration = kSlidingDrawersAnimationDuration});

  void slideTo(double value, {Duration? duration, Curve? curve});
}

class SlidingDrawerBounds {
  const SlidingDrawerBounds({
    required this.minHeight,
    required this.maxHeight,
    required this.measuredHeight,
  })  : assert(minHeight >= 0 && maxHeight >= minHeight,
            "($minHeight) >= 0 && ($maxHeight) >= ($minHeight) is not true."),
        assert(measuredHeight == null || measuredHeight >= 0);

  final double minHeight;
  final double maxHeight;
  final double? measuredHeight;

  double get maxSlide => maxHeight - minHeight;

  double? normalizedHeightOf(
      {double? height, double? slide, double? transition}) {
    assert(slide == null || height == null || transition == null);
    assert(transition == null || (transition >= 0 && transition <= 1));

    if (transition != null) {
      slide = maxSlide * transition;
    }

    if (slide != null) {
      height = maxHeight - slide;
    }

    return height?.clamp(minHeight, maxHeight);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is SlidingDrawerBounds &&
        other.minHeight == minHeight &&
        other.maxHeight == maxHeight &&
        other.measuredHeight == measuredHeight;
  }

  @override
  int get hashCode => Object.hash(minHeight, maxHeight, measuredHeight);

  @override
  String toString() {
    return "SlidingDrawerBounds: $minHeight <= height <= $maxHeight";
  }
}
