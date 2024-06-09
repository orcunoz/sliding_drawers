## Usage

```dart
SlidingDrawersArea(
    topDrawers: [
        SlidingDrawer(
            slideDirection: VerticalDirection.up,
            slidePriority: 2,
            child: Container(
                height: 80,
                color: Colors.red,
                alignment: Alignment.center,
                child: const Text("Drawer 1"),
            ),
        ),
        SlidingDrawer(
            slideDirection: VerticalDirection.up,
            slidePriority: 3,
            child: Container(
                height: 80,
                color: Colors.blue,
                alignment: Alignment.center,
                child: const Text("Drawer 2"),
            ),
        ),
        SlidingDrawer(
            slideDirection: VerticalDirection.up,
            slidePriority: 1,
            snap: true,
            child: Container(
                height: 80,
                color: Colors.orange,
                alignment: Alignment.center,
                child: const Text("Drawer 3"),
            ),
        ),
    ],
    child: SlidingDrawersScrollable(
        fillViewport: true,
        child: Container(
            color: Colors.black12,
            alignment: Alignment.center,
            child: const Text("Body"),
        ),
    ),
)
```
