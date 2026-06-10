import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:coding_agent_dock/l10n/app_localizations.dart';
import 'package:coding_agent_dock/widgets/attachment_strip.dart';

/// Minimal valid 1×1 red PNG.
final Uint8List kTinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAE'
  'hQGAhKmMIQAAAABJRU5ErkJggg==',
);

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('attachment_strip_test');
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  testWidgets('PNG attachment renders a real image thumbnail, not an icon',
      (tester) async {
    final file = File('${tempDir.path}/shot.png')
      ..writeAsBytesSync(kTinyPng);

    await tester.runAsync(() async {
      await tester.pumpWidget(_host(AttachmentStrip(
        attachments: [file.path],
        running: true,
        onPreview: (_) {},
        onRemove: (_) {},
        onClear: () {},
        onInsert: () {},
      )));

      // Image widget must be on the image branch (not the file-icon branch).
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget,
          reason: 'expected the Image.file branch for a .png path');

      // Force the actual decode of the file — fails the test on any
      // decode error instead of silently hitting errorBuilder.
      final Image img = tester.widget(imageFinder);
      await precacheImage(img.image, tester.element(imageFinder));
      await tester.pump();
    });

    expect(find.byIcon(Icons.broken_image_outlined), findsNothing,
        reason: 'decode must succeed for a valid PNG');
    expect(find.byIcon(Icons.insert_drive_file_outlined), findsNothing,
        reason: '.png must never fall into the generic-file branch');
  });

  testWidgets('non-image attachment shows the file icon with extension',
      (tester) async {
    final file = File('${tempDir.path}/notes.txt')
      ..writeAsStringSync('hello');

    await tester.pumpWidget(_host(AttachmentStrip(
      attachments: [file.path],
      running: true,
      onPreview: (_) {},
      onRemove: (_) {},
      onClear: () {},
      onInsert: () {},
    )));

    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.insert_drive_file_outlined), findsOneWidget);
    expect(find.text('TXT'), findsOneWidget);
  });

  testWidgets('corrupt image file surfaces the broken-image state',
      (tester) async {
    final file = File('${tempDir.path}/broken.png')
      ..writeAsBytesSync([1, 2, 3, 4]);

    await tester.runAsync(() async {
      await tester.pumpWidget(_host(AttachmentStrip(
        attachments: [file.path],
        running: true,
        onPreview: (_) {},
        onRemove: (_) {},
        onClear: () {},
        onInsert: () {},
      )));
      // Let the failed decode propagate to errorBuilder.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });

    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  testWidgets('tapping a thumbnail invokes onPreview with the path',
      (tester) async {
    final file = File('${tempDir.path}/shot.png')
      ..writeAsBytesSync(kTinyPng);
    String? previewed;

    await tester.runAsync(() async {
      await tester.pumpWidget(_host(AttachmentStrip(
        attachments: [file.path],
        running: true,
        onPreview: (p) => previewed = p,
        onRemove: (_) {},
        onClear: () {},
        onInsert: () {},
      )));
    });

    await tester.tap(find.byType(AttachmentThumb));
    expect(previewed, file.path);
  });
}
