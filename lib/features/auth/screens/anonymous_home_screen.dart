import 'package:flutter/material.dart';
import '../../../core/l10n/l10n.dart';

class AnonymousHomeScreen extends StatelessWidget {
  const AnonymousHomeScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(L10n.appName(context))));
}