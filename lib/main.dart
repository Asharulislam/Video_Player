import 'package:flutter/material.dart';
import 'package:my_project_name/chewie_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: prefer_const_constructors
    return MaterialApp(
      title: 'Flutter Demo',
      home: const VideoPlayerScreen(),
    );
  }
}
