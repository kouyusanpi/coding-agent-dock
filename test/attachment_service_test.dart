import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:claude_code_cli_flutter/services/attachment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AttachmentService.clipboardPaths', () {
    const channel = MethodChannel('pasteboard');

    void mockPasteboard({List<String>? files, List<int>? image}) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        switch (call.method) {
          case 'files':
            return files;
          case 'image':
            return image == null ? null : Uint8List.fromList(image);
          default:
            return null;
        }
      });
    }

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('prefers copied FILE paths over image bytes (Finder Cmd+C case)',
        () async {
      // A real existing file on disk, plus image bytes that would be the
      // file's ICON — the path must win.
      final dir = Directory.systemTemp.createTempSync('clip_test');
      final real = File('${dir.path}/photo.png')..writeAsBytesSync([1]);
      addTearDown(() => dir.deleteSync(recursive: true));

      mockPasteboard(files: [real.path], image: [9, 9, 9]);

      final paths = await AttachmentService.clipboardPaths();
      expect(paths, [real.path]);
    });

    test('falls back to image bytes when clipboard has no files', () async {
      mockPasteboard(files: [], image: [1, 2, 3]);

      final paths = await AttachmentService.clipboardPaths();
      expect(paths, hasLength(1));
      expect(paths.single, endsWith('.png'));
      final saved = File(paths.single);
      expect(saved.existsSync(), isTrue);
      expect(saved.readAsBytesSync(), [1, 2, 3]);
      saved.deleteSync();
    });

    test('ignores non-existent clipboard file paths', () async {
      mockPasteboard(
          files: ['/definitely/not/here.png'], image: [7, 7]);

      final paths = await AttachmentService.clipboardPaths();
      // Bogus path skipped → falls through to image bytes.
      expect(paths, hasLength(1));
      expect(File(paths.single).readAsBytesSync(), [7, 7]);
      File(paths.single).deleteSync();
    });

    test('returns empty when clipboard has neither files nor image',
        () async {
      mockPasteboard(files: [], image: null);
      expect(await AttachmentService.clipboardPaths(), isEmpty);
    });
  });

  group('AttachmentService.quotePath', () {
    test('leaves simple paths untouched', () {
      expect(AttachmentService.quotePath('/tmp/img.png'), '/tmp/img.png');
    });

    test('quotes paths containing spaces', () {
      expect(AttachmentService.quotePath('/tmp/my file.png'),
          "'/tmp/my file.png'");
    });

    test('escapes single quotes inside paths', () {
      expect(AttachmentService.quotePath("/tmp/it's.png"),
          r"'/tmp/it'\''s.png'");
    });
  });

  group('AttachmentService.isImagePath', () {
    test('recognizes common image extensions case-insensitively', () {
      expect(AttachmentService.isImagePath('/tmp/a.png'), isTrue);
      expect(AttachmentService.isImagePath('/tmp/a.JPG'), isTrue);
      expect(AttachmentService.isImagePath('/tmp/a.jpeg'), isTrue);
      expect(AttachmentService.isImagePath('/tmp/a.webp'), isTrue);
      expect(AttachmentService.isImagePath('/tmp/shot.HEIC'), isTrue);
    });

    test('rejects non-image files and extensionless paths', () {
      expect(AttachmentService.isImagePath('/tmp/a.txt'), isFalse);
      expect(AttachmentService.isImagePath('/tmp/a.pdf'), isFalse);
      expect(AttachmentService.isImagePath('/tmp/noext'), isFalse);
      expect(AttachmentService.isImagePath('/tmp/trailingdot.'), isFalse);
    });
  });

  group('AttachmentService.formatPaths', () {
    test('joins multiple paths with spaces and a trailing space', () {
      expect(
        AttachmentService.formatPaths(['/a.png', '/b dir/c.png']),
        "/a.png '/b dir/c.png' ",
      );
    });

    test('single path gets a trailing space for continued typing', () {
      expect(AttachmentService.formatPaths(['/a.png']), '/a.png ');
    });
  });
}
