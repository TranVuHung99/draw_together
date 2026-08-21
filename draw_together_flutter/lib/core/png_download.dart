/// Hands finished PNG bytes to the platform.
///
/// The browser gets a download; anywhere else the file is written to disk.
/// Nothing here runs unless a player asks for an export.
library;

export 'png_download_io.dart'
    if (dart.library.js_interop) 'png_download_web.dart';
