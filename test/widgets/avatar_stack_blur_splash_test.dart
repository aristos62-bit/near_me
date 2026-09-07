import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me/shared/widgets/avatar_stack.dart';
import 'package:near_me/shared/widgets/blur_reveal_image.dart';
import 'package:near_me/shared/widgets/splash_screen.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('el'),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('el'), Locale('en')],
    home: Scaffold(body: child),
  );
}

void main() {
  group('AvatarStack', () {
    testWidgets('εμφανίζει αρχικά όλων των uids', (tester) async {
      await tester.pumpWidget(_wrap(
        const AvatarStack(uids: ['Alice', 'Bob', 'Carol']),
      ));
      // 3 CircleAvatars
      expect(find.byType(CircleAvatar), findsNWidgets(3));
      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
    });

    testWidgets('χρησιμοποιεί το nickname για το αρχικό', (tester) async {
      await tester.pumpWidget(_wrap(
        const AvatarStack(
          uids: ['u1'],
          nicknames: {'u1': 'Nikolas'},
        ),
      ));
      expect(find.text('N'), findsOneWidget);
    });

    testWidgets('overflow: εμφανίζει +N για επιπλέον uids', (tester) async {
      await tester.pumpWidget(_wrap(
        const AvatarStack(
          uids: ['a', 'b', 'c', 'd', 'e'],
          maxVisible: 3,
        ),
      ));
      // 3 ορατά + 1 overflow badge = 4 CircleAvatar
      expect(find.byType(CircleAvatar), findsNWidgets(4));
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('κενό uid → placeholder ?', (tester) async {
      await tester.pumpWidget(_wrap(
        const AvatarStack(uids: ['']),
      ));
      expect(find.text('?'), findsOneWidget);
    });
  });

  group('SplashScreen', () {
    testWidgets('εμφανίζει loading indicator', (tester) async {
      await tester.pumpWidget(_wrap(const SplashScreen()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });
  });

  group('BlurRevealImage', () {
    testWidgets('χωρίς blur → εμφανίζει την εικόνα χωρίς overlay', (tester) async {
      await tester.pumpWidget(_wrap(
        const BlurRevealImage(imageUrl: 'https://example.com/img.jpg'),
      ));
      await tester.pump();
      // Δεν εμφανίζεται κουμπί reveal / visibility_off
      expect(find.byIcon(Icons.visibility_off), findsNothing);
      expect(find.text('Εμφάνιση'), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('blur on + racy → εμφανίζει overlay με κουμπί reveal', (tester) async {
      await tester.pumpWidget(_wrap(
        const BlurRevealImage(
          imageUrl: 'https://example.com/img.jpg',
          racyLevel: 'POSSIBLE',
          blurEnabled: true,
          blurSigma: 12,
        ),
      ));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(find.text('Εμφάνιση'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('tap στο overlay → αποκαλύπτει (αφαιρεί το blur)', (tester) async {
      await tester.pumpWidget(_wrap(
        const BlurRevealImage(
          imageUrl: 'https://example.com/img.jpg',
          racyLevel: 'POSSIBLE',
          blurEnabled: true,
          blurSigma: 12,
        ),
      ));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      await tester.tap(find.byType(BlurRevealImage));
      await tester.pump();
      // Μετά το reveal το overlay φεύγει
      expect(find.byIcon(Icons.visibility_off), findsNothing);
      await tester.pump(const Duration(seconds: 2));
    });
  });
}