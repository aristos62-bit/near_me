import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/features/chat/widgets/emoji_only_bubble.dart';
import 'package:near_me/features/chat/widgets/message_bubble/audio_message_bubble.dart';
import 'package:near_me/features/chat/widgets/message_bubble/gif_image_bubble.dart';
import 'package:near_me/features/chat/widgets/message_bubble/message_bubble.dart';
import 'package:near_me/features/chat/widgets/message_bubble/message_callbacks.dart';
import 'package:near_me/features/chat/widgets/message_bubble/system_message_bubble.dart';
import 'package:near_me/features/chat/widgets/message_bubble/text_message_bubble.dart';
import 'package:near_me/features/chat/widgets/message_bubble/video_message_bubble.dart';

Widget wrap({
  required Map<String, dynamic> message,
  String currentUid = 'me',
  String? chatId,
  MessageCallbacks callbacks = const MessageCallbacks(),
}) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('el'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('el'), Locale('en')],
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            child: MessageBubble(
              message: message,
              bubbleMaxWidth: 300,
              currentUid: currentUid,
              chatId: chatId,
              callbacks: callbacks,
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  group('MessageBubble type dispatch', () {
    testWidgets('text type renders TextMessageBubble', (tester) async {
      await tester.pumpWidget(wrap(message: {
        'type': 'text',
        'content': 'hello',
        'senderId': 'other',
        'id': 'm1',
      }));
      expect(find.byType(TextMessageBubble), findsOneWidget);
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('missing type falls back to TextMessageBubble', (tester) async {
      await tester.pumpWidget(wrap(message: {
        'content': 'no type',
        'senderId': 'other',
      }));
      expect(find.byType(TextMessageBubble), findsOneWidget);
      expect(find.text('no type'), findsOneWidget);
    });

    testWidgets('emoji-only text renders EmojiOnlyBubble', (tester) async {
      await tester.pumpWidget(wrap(message: {
        'type': 'text',
        'content': '😀',
        'senderId': 'other',
        'id': 'm1',
      }));
      expect(find.byType(EmojiOnlyBubble), findsOneWidget);
      expect(find.byType(TextMessageBubble), findsNothing);
    });

    testWidgets('mixed text with emoji stays TextMessageBubble', (tester) async {
      await tester.pumpWidget(wrap(message: {
        'type': 'text',
        'content': 'Hello 😀',
        'senderId': 'other',
        'id': 'm1',
      }));
      expect(find.byType(TextMessageBubble), findsOneWidget);
      expect(find.byType(EmojiOnlyBubble), findsNothing);
    });

    testWidgets('audio type renders AudioMessageBubble with fields',
        (tester) async {
      await tester.pumpWidget(wrap(message: {
        'type': 'audio',
        'content': 'https://cdn.example/audio.mp3',
        'duration': 65,
        'senderId': 'other',
        'id': 'm1',
        'timestamp': Timestamp.fromMillisecondsSinceEpoch(1700000000000),
      }));
      final bubble =
          tester.widget<AudioMessageBubble>(find.byType(AudioMessageBubble));
      expect(bubble.content, 'https://cdn.example/audio.mp3');
      expect(bubble.duration, 65);
      expect(bubble.isMe, isFalse);
    });

    testWidgets('video type renders VideoMessageBubble', (tester) async {
      await tester.pumpWidget(wrap(message: {
        'type': 'video',
        'content': 'https://cdn.example/video.mp4',
        'duration': 12,
        'thumbnailUrl': 'https://cdn.example/thumb.jpg',
        'senderId': 'other',
        'id': 'm1',
      }));
      final bubble =
          tester.widget<VideoMessageBubble>(find.byType(VideoMessageBubble));
      expect(bubble.content, 'https://cdn.example/video.mp4');
      expect(bubble.duration, 12);
      await _settle(tester);
    });

    testWidgets('image type renders GifImageBubble with isImage=true',
        (tester) async {
      await tester.pumpWidget(wrap(message: {
        'type': 'image',
        'content': 'https://cdn.example/photo.jpg',
        'senderId': 'other',
        'id': 'm1',
      }));
      final bubble =
          tester.widget<GifImageBubble>(find.byType(GifImageBubble));
      expect(bubble.content, 'https://cdn.example/photo.jpg');
      expect(bubble.isImage, isTrue);
      await _settle(tester);
    });

    testWidgets('gif type renders GifImageBubble with isImage=false',
        (tester) async {
      await tester.pumpWidget(wrap(message: {
        'type': 'gif',
        'content': 'https://media.giphy.com/x.gif',
        'senderId': 'other',
        'id': 'm1',
      }));
      final bubble =
          tester.widget<GifImageBubble>(find.byType(GifImageBubble));
      expect(bubble.content, 'https://media.giphy.com/x.gif');
      expect(bubble.isImage, isFalse);
      await _settle(tester);
    });
  });

  group('MessageBubble system branch', () {
    testWidgets('passes content, contentEn, action and chatId',
        (tester) async {
      await tester.pumpWidget(wrap(
        chatId: 'chat1',
        message: {
          'type': 'system',
          'content': 'σύστημα',
          'contentEn': 'system',
          'action': 'delete_request',
          'senderId': 'me',
          'id': 'm1',
        },
      ));
      final sys =
          tester.widget<SystemMessageBubble>(find.byType(SystemMessageBubble));
      expect(sys.content, 'σύστημα');
      expect(sys.contentEn, 'system');
      expect(sys.action, 'delete_request');
      expect(sys.chatId, 'chat1');
    });

    testWidgets('isRequester true when sender is current user', (tester) async {
      await tester.pumpWidget(wrap(
        chatId: 'chat1',
        message: {
          'type': 'system',
          'content': 'delete',
          'action': 'delete_request',
          'senderId': 'me',
        },
      ));
      final sys =
          tester.widget<SystemMessageBubble>(find.byType(SystemMessageBubble));
      expect(sys.isRequester, isTrue);
    });

    testWidgets('isRequester false for another sender', (tester) async {
      await tester.pumpWidget(wrap(
        chatId: 'chat1',
        message: {
          'type': 'system',
          'content': 'delete',
          'action': 'delete_request',
          'senderId': 'other',
        },
      ));
      final sys =
          tester.widget<SystemMessageBubble>(find.byType(SystemMessageBubble));
      expect(sys.isRequester, isFalse);
    });
  });

  group('MessageBubble text/rich content', () {
    testWidgets('mentions render rich highlighted spans', (tester) async {
      await tester.pumpWidget(wrap(message: {
        'type': 'text',
        'content': '@Nick check this',
        'senderId': 'other',
        'id': 'm1',
        'mentions': ['uid2'],
        'participantNicknames': {'uid2': 'Nick'},
      }));
      expect(
        find.textContaining('@Nick', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('link span triggers onLinkTap', (tester) async {
      final tappedUrls = <String>[];
      await tester.pumpWidget(wrap(
        callbacks: MessageCallbacks(onLinkTap: (url) => tappedUrls.add(url)),
        message: {
          'type': 'text',
          'content': 'https://example.com',
          'senderId': 'other',
          'id': 'm1',
        },
      ));
      await tester.tap(find.descendant(
        of: find.byType(MessageBubble),
        matching: find.byType(RichText),
      ));
      expect(tappedUrls, ['https://example.com']);
    });
  });

  group('MessageBubble edge cases', () {
    testWidgets('no timestamp renders without crashing', (tester) async {
      await tester.pumpWidget(wrap(message: {
        'type': 'text',
        'content': 'no ts',
        'senderId': 'other',
      }));
      expect(tester.takeException(), isNull);
      expect(find.byType(TextMessageBubble), findsOneWidget);
    });

    testWidgets('reactions with my emoji shown via reaction icon',
        (tester) async {
      await tester.pumpWidget(wrap(
        chatId: 'chat1',
        message: {
          'type': 'text',
          'content': 'hi',
          'senderId': 'me',
          'id': 'm1',
          'reactions': {'me': '❤️'},
        },
      ));
      expect(find.text('❤️'), findsOneWidget);
    });
  });
}