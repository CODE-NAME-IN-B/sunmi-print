# Vendored third-party packages

Packages here are published sources with local patches. Each one is patched
because its published release cannot build against the toolchain this app pins,
and a newer release does not exist. Patching the copy in `~/.pub-cache` instead
makes a local build pass while leaving CI broken, because CI fetches a pristine
archive from pub.dev.

`tool/verify_vendor_patches.sh` re-downloads each archive from pub.dev and
fails if the vendored copy differs by anything other than the patches listed in
`vendor-patches.json`. Run it after `flutter pub get`, and before blaming a
strange build error on your own code.

## pdf_render 1.4.12

`PdfRenderPlugin.kt` imports `io.flutter.plugin.common.PluginRegistry.Registrar`.
That type was removed from the Flutter engine, so the Kotlin compiler fails with
`Unresolved reference 'Registrar'` and the whole release build fails. The import
is never used: it is a leftover from the plugin's pre-embedding API. Removing the
line is therefore provably inert, and 1.4.12 is the last published version, so
there is no upgrade to take instead.

Trimmed to `lib/` and `android/`, which is all this app consumes. The upstream
`example/`, `images/`, `ios/`, `macos/` and `test/` directories are not needed
here and are not carried along.
