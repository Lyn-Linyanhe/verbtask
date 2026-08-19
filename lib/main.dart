import 'package:flutter/material.dart';

void main() => runApp(const VerbApp());

class VerbApp extends StatelessWidget {
  const VerbApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Verb Task',
      theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
      home: const Scaffold(body: Center(child: Text('Verb Task'))),
    );
  }
}
