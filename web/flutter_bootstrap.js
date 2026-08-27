{{flutter_js}}
{{flutter_build_config}}

// Keep the renderer inside the deployed web bundle. This prevents a blocked or
// slow third-party CDN from leaving CHEKMI on a blank page during startup.
_flutter.loader.load({
  config: {
    canvasKitBaseUrl: 'canvaskit/',
  },
});
