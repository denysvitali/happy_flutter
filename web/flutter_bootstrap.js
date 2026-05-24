{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    // Keep the CanvasKit overlay surface cap without predefining
    // window.flutterCanvasKit, which is owned by Flutter's engine loader.
    canvasKitMaximumSurfaces: 8,
  },
});
