import 'package:dnaolfativo/data/profile_store.dart';
import 'package:dnaolfativo/domain/questionnaire.dart';
import 'package:dnaolfativo/presentation/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProfileStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'questionnaire_page': 4,
      'questionnaire_page_quick': 1,
      'questionnaire_page_detailed': 7,
    });
    store = await ProfileStore.load();
  });
  test(
    'reset apaga ambas as versões, desconhecidos e retomada; permanece vazio ao reabrir',
    () async {
      await store.setRating(1, 9);
      await store.setRating(3, 2); // Item only in the detailed version.
      await store.markUnknown(16);
      await store.selectMode(QuestionnaireMode.quick);
      expect(store.perfumeRanking, isNotEmpty);
      await store.clear();
      expect(store.ratings, isEmpty);
      expect(store.unknownOdors, isEmpty);
      expect(store.mode, QuestionnaireMode.detailed);
      expect(
        store.scores.every((s) => s.score == null && s.evidence == 0),
        true,
      );
      expect(store.perfumeRanking, isEmpty);
      for (final key in [
        'questionnaire_page',
        'questionnaire_page_quick',
        'questionnaire_page_detailed',
      ]) {
        expect(store.prefs.containsKey(key), false);
      }
      final reopened = await ProfileStore.load();
      expect(reopened.ratings, isEmpty);
      expect(reopened.unknownOdors, isEmpty);
      expect(reopened.perfumeRanking, isEmpty);
      await reopened.clear(); // Repeated reset is safe.
    },
  );
  testWidgets(
    'botão visível confirma, cancela sem perda e recomeça sem busca nem filtros',
    (tester) async {
      await tester.runAsync(() async {
        await store.setRating(85, 9);
        await store.setRating(3, 8);
        await store.markUnknown(16);
        await store.selectMode(QuestionnaireMode.quick);
      });
      await tester.pumpWidget(DnaApp(store: store));
      expect(find.byTooltip('Resetar toda a pesquisa'), findsOneWidget);
      await tester.tap(find.text('Avaliar'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'limão');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Avaliados'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Resetar toda a pesquisa'));
      await tester.tap(find.text('Resetar toda a pesquisa'));
      await tester.pumpAndSettle();
      expect(find.text('Resetar toda a pesquisa?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(store.ratings.length, 2);
      expect(store.unknownOdors.length, 1);
      expect(store.prefs.getInt('questionnaire_page_detailed'), 7);
      await tester.tap(find.text('Mapa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resetar toda a pesquisa'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      // Wait for the queued platform storage removals, not only UI animations.
      for (
        var attempt = 0;
        attempt < 30 &&
            find.text('Descubra seu DNA Olfativo').evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump();
      }
      expect(find.text('Descubra seu DNA Olfativo'), findsOneWidget);
      expect(store.ratings, isEmpty);
      expect(store.unknownOdors, isEmpty);
      expect(store.perfumeRanking, isEmpty);
      await tester.ensureVisible(find.text('Começar'));
      await tester.tap(find.text('Começar'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 14'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text ?? '',
        isEmpty,
      );
      final all = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Todos'),
      );
      expect(all.selected, true);
      expect(find.byType(Slider), findsNWidgets(12));
      expect(tester.takeException(), isNull);
    },
  );
}
