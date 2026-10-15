import 'package:flutter/material.dart';
import 'data/profile_store.dart';
import 'presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    runApp(DnaApp(store: await ProfileStore.load()));
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Não foi possível abrir os dados. Preserve seu backup e reinicie. $e',
            ),
          ),
        ),
      ),
    );
  }
}
