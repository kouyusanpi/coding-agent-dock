import 'dart:io';
import 'dart:typed_data';

import 'package:pasteboard/pasteboard.dart';

/// Helpers for getting images/files into a terminal session's prompt.
///
/// CLIs like Claude Code accept image *file paths* inside the prompt text,
/// so "paste an image" means: save the clipboard image to a temp file and
/// type its path into the PTY.
class AttachmentService {
  AttachmentService._();

  /// Directory where pasted clipboard images are stored.
  static Directory get _pasteDir =>
      Directory('${Directory.systemTemp.path}/agentdock_paste');

  static const Set<String> _imageExts = {
    'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp', 'heic', 'heif', 'tiff', 'svg',
  };

  /// Whether [path] looks like an image file (by extension).
  /// Trims whitespace so stray spaces/newlines never break detection.
  static bool isImagePath(String path) {
    final p = path.trim();
    final dot = p.lastIndexOf('.');
    if (dot == -1 || dot == p.length - 1) return false;
    return _imageExts.contains(p.substring(dot + 1).toLowerCase());
  }

  /// Quote a path for shell-/CLI-safe insertion into the prompt.
  /// Wraps in single quotes when it contains whitespace or quotes.
  static String quotePath(String path) {
    if (path.contains(RegExp(r'''[\s'"]'''))) {
      return "'${path.replaceAll("'", r"'\''")}'";
    }
    return path;
  }

  /// Join multiple paths, quoted, space-separated, with a trailing space so
  /// the user can keep typing after the insertion.
  static String formatPaths(Iterable<String> paths) =>
      '${paths.map(quotePath).join(' ')} ';

  /// Resolve the clipboard into attachable file paths.
  ///
  /// Copied FILES (Finder Cmd+C) take priority: in that case the pasteboard
  /// also carries the file's ICON as image data, so reading `Pasteboard.image`
  /// first would attach a picture of the icon instead of the real file.
  /// Falls back to raw image bytes (screenshots, copied bitmap data) saved
  /// to a temp PNG. Returns an empty list when the clipboard has neither.
  static Future<List<String>> clipboardPaths() async {
    try {
      final files = await Pasteboard.files();
      final existing = files
          .where((p) => p.isNotEmpty && File(p).existsSync())
          .toList();
      if (existing.isNotEmpty) return existing;
    } catch (_) {
      // files() unsupported/failed — fall through to image bytes.
    }
    final saved = await saveClipboardImage();
    return saved == null ? const [] : [saved];
  }

  /// If the system clipboard currently holds an image, write it to a temp
  /// PNG file and return the path. Returns null when there is no image.
  static Future<String?> saveClipboardImage() async {
    final Uint8List? bytes = await Pasteboard.image;
    if (bytes == null || bytes.isEmpty) return null;
    final dir = _pasteDir;
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final path =
        '${dir.path}/paste_${DateTime.now().millisecondsSinceEpoch}.png';
    await File(path).writeAsBytes(bytes);
    return path;
  }

  /// Delete pasted images older than [maxAge] (best-effort housekeeping).
  static Future<void> cleanOldPastes(
      {Duration maxAge = const Duration(days: 3)}) async {
    try {
      final dir = _pasteDir;
      if (!dir.existsSync()) return;
      final cutoff = DateTime.now().subtract(maxAge);
      for (final f in dir.listSync().whereType<File>()) {
        if (f.statSync().modified.isBefore(cutoff)) f.deleteSync();
      }
    } catch (_) {}
  }
}
