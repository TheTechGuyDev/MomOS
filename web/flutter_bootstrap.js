{{flutter_js}}
{{flutter_build_config}}

// MomOS registers its own service worker (push-sw.js) for notifications,
// so Flutter's deprecated service worker is not used.
_flutter.loader.load();
