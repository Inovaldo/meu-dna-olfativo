import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../data/profile_store.dart';
import '../domain/profile.dart';
import '../domain/questionnaire.dart';
import 'report.dart';
import 'family_chart.dart';
import 'perfume_ranking.dart';
import 'perfume_catalog.dart';

String decimal(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

class DnaApp extends StatefulWidget {
  final ProfileStore store;
  const DnaApp({super.key, required this.store});
  @override
  State<DnaApp> createState() => _DnaAppState();
}

class _DnaAppState extends State<DnaApp> {
  ThemeMode mode = ThemeMode.system;
  @override
  Widget build(BuildContext c) => MaterialApp(
    title: 'Meu DNA Olfativo',
    debugShowCheckedModeBanner: false,
    themeMode: mode,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSans',
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff235f53)),
      scaffoldBackgroundColor: const Color(0xfff6f5ef),
    ),
    darkTheme: ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSans',
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff80cbb8),
        brightness: Brightness.dark,
      ),
    ),
    home: Home(
      store: widget.store,
      mode: mode,
      onTheme: (v) => setState(() => mode = v),
    ),
  );
}

class Home extends StatefulWidget {
  final ProfileStore store;
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onTheme;
  const Home({
    super.key,
    required this.store,
    required this.mode,
    required this.onTheme,
  });
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0, page = 0;
  String search = '', filter = 'Todos';
  ProfileStore get s => widget.store;
  final scroll = ScrollController();
  final perfumeSection = GlobalKey();
  bool resetting = false;
  @override
  void initState() {
    super.initState();
    page = savedPage();
  }

  int savedPage() =>
      s.prefs.getInt('questionnaire_page_${s.mode.name}') ??
      (s.mode == QuestionnaireMode.detailed
          ? s.prefs.getInt('questionnaire_page') ?? 0
          : 0);

  Future<void> chooseMode(QuestionnaireMode mode) async {
    await s.selectMode(mode);
    if (!mounted) return;
    setState(() {
      page = savedPage();
      search = '';
      filter = 'Todos';
    });
  }

  void showResult() {
    setState(() => tab = 2);
    scroll.jumpTo(0);
  }

  void openCatalog() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          PerfumeCatalogPage(perfumes: s.perfumes, families: s.families),
    ),
  );

  Future<void> resetResearch() async {
    if (resetting) return;
    final confirmed = await confirm(
      'Resetar toda a pesquisa?',
      'Todas as notas, respostas “Não sei o cheiro” e o progresso das versões rápida e completa serão apagados. O mapa e o ranking de perfumes também serão zerados. Deseja recomeçar?',
    );
    if (!confirmed || !mounted || resetting) return;
    setState(() => resetting = true);
    try {
      await s.clear();
      if (!mounted) return;
      setState(() {
        tab = 0;
        page = 0;
        search = '';
        filter = 'Todos';
      });
      scroll.jumpTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pesquisa resetada. Você já pode começar novamente.'),
        ),
      );
    } finally {
      if (mounted) setState(() => resetting = false);
    }
  }

  Widget resetButton() => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: OutlinedButton.icon(
      onPressed: resetting ? null : () => action(resetResearch),
      icon: const Icon(Icons.restart_alt),
      label: const Text('Resetar toda a pesquisa'),
    ),
  );

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Future<void> action(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível concluir: $e')),
        );
      }
    }
  }

  Future<bool> confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ) ??
      false;
  Widget heading(String eyebrow, String title, String subtitle) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            letterSpacing: 2,
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
  @override
  Widget build(BuildContext c) => ListenableBuilder(
    listenable: s,
    builder: (c, _) {
      final bodies = [
        welcome,
        questionnaire,
        map,
        discoveries,
        report,
        settings,
      ];
      return Scaffold(
        appBar: AppBar(
          title: const Text('Meu DNA Olfativo'),
          actions: [
            IconButton(
              tooltip: 'Catálogo de perfumes',
              onPressed: openCatalog,
              icon: const Icon(Icons.menu_book_outlined),
            ),
            IconButton(
              tooltip: 'Resetar toda a pesquisa',
              onPressed: resetting ? null : () => action(resetResearch),
              icon: const Icon(Icons.restart_alt),
            ),
            IconButton(
              tooltip: 'Configurações',
              onPressed: () => setState(() => tab = 5),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: SingleChildScrollView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: bodies[tab](),
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: min(tab, 4),
          onDestinationSelected: (v) {
            setState(() => tab = v);
            scroll.jumpTo(0);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.spa_outlined),
              label: 'Início',
            ),
            NavigationDestination(icon: Icon(Icons.tune), label: 'Avaliar'),
            NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Mapa'),
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              label: 'Descobertas',
            ),
            NavigationDestination(
              icon: Icon(Icons.description_outlined),
              label: 'Relatório',
            ),
          ],
        ),
      );
    },
  );
  Widget welcome() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'Uma jornada pelos sentidos',
        'Descubra seu DNA Olfativo',
        'Memórias, sensações e cheiros do dia a dia. Encontre as afinidades que fazem parte de você.',
      ),
      OutlinedButton.icon(
        onPressed: openCatalog,
        icon: const Icon(Icons.menu_book_outlined),
        label: const Text('Explorar os 150 perfumes'),
      ),
      const SizedBox(height: 20),
      Text(
        'Como você quer descobrir?',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('Rápido · 24 cheiros'),
            selected: s.mode == QuestionnaireMode.quick,
            onSelected: (_) =>
                action(() => chooseMode(QuestionnaireMode.quick)),
          ),
          ChoiceChip(
            label: const Text('Completo · 157 cheiros'),
            selected: s.mode == QuestionnaireMode.detailed,
            onSelected: (_) =>
                action(() => chooseMode(QuestionnaireMode.detailed)),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Text(
        s.mode == QuestionnaireMode.quick
            ? 'Uma noção geral: 24 cheiros conhecidos do dia a dia, com 2 exemplos de cada uma das 12 famílias.'
            : 'Mais detalhes: explore os 157 cheiros e construa um retrato com mais evidências.',
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.spa_outlined,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Seu gosto é o ponto de partida',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Dê notas de 0 (Detesto) a 10 (Adoro), de meio em meio. Uma nota 5 significa indiferença. Se não conhece um cheiro, escolha “Não sei o cheiro”: ele não entra nos cálculos.',
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  setState(() => tab = 1);
                  scroll.jumpTo(0);
                },
                icon: const Icon(Icons.arrow_forward),
                label: Text(s.answeredCount == 0 ? 'Começar' : 'Continuar'),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 24),
      Text(
        '${s.questionnaire.length} cheiros cotidianos • 12 famílias • No seu ritmo',
      ),
      const SizedBox(height: 8),
      const Text(
        'Você pode trocar de versão sem perder respostas. O resultado usa as notas dos cheiros da versão escolhida.',
      ),
      const SizedBox(height: 12),
      const Text(
        'Suas respostas ficam neste aparelho. Funciona offline, sem conta e sem coleta de dados pessoais.',
      ),
    ],
  );
  Widget questionnaire() {
    final items = s.questionnaire
        .where(
          (o) =>
              o.name.toLowerCase().contains(search.toLowerCase()) &&
              (filter == 'Todos' ||
                  filter == 'Sem avaliação' &&
                      !s.ratings.containsKey(o.id) &&
                      !s.unknownOdors.containsKey(o.id) ||
                  filter == 'Avaliados' && s.ratings.containsKey(o.id) ||
                  filter == 'Não sei o cheiro' &&
                      s.unknownOdors.containsKey(o.id)),
        )
        .toList();
    final pages = max(1, (items.length / 12).ceil()),
        current = min(page, pages - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          s.mode == QuestionnaireMode.quick
              ? 'Versão rápida · 24 cheiros'
              : 'Versão completa · 157 cheiros',
          'Que cheiro combina com você?',
          'Avalie o que conhece. “Não sei o cheiro” fica fora dos cálculos.',
        ),
        resetButton(),
        Text(
          '${s.answeredCount} de ${s.questionnaire.length} respondidos · ${s.ratedCount} com nota · ${s.unknownCount} não conheço',
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: s.answeredCount / s.questionnaire.length,
        ),
        const SizedBox(height: 20),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Buscar cheiro',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() {
            search = v;
            page = 0;
          }),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final f in [
              'Todos',
              'Sem avaliação',
              'Avaliados',
              'Não sei o cheiro',
            ])
              ChoiceChip(
                label: Text(f),
                selected: f == filter,
                onSelected: (_) => setState(() {
                  filter = f;
                  page = 0;
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty) const Text('Nenhum cheiro encontrado.'),
        for (final o in items.skip(current * 12).take(12))
          OdorCard(
            odor: o,
            value: s.ratings[o.id]?.value,
            unknown: s.unknownOdors.containsKey(o.id),
            onUnknown: () => action(() => s.markUnknown(o.id)),
            onChanged: (v) => action(() => s.setRating(o.id, v)),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: current == 0
                  ? null
                  : () => setState(() {
                      page = current - 1;
                      scroll.jumpTo(0);
                    }),
              child: const Text('Anterior'),
            ),
            Text('${current + 1} / $pages'),
            TextButton(
              onPressed: current == pages - 1
                  ? null
                  : () => setState(() {
                      page = current + 1;
                      scroll.jumpTo(0);
                    }),
              child: const Text('Próximo'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: showResult,
          icon: const Icon(Icons.bar_chart),
          label: Text(
            current == pages - 1
                ? 'Concluir e ver meu resultado'
                : 'Ver meu resultado parcial',
          ),
        ),
        if (s.answeredCount == s.questionnaire.length)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Você terminou esta versão! Os cheiros que não conhece foram excluídos dos cálculos.',
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => action(() async {
            await s.prefs.setInt('questionnaire_page_${s.mode.name}', current);
            if (mounted) setState(() => tab = 0);
          }),
          icon: const Icon(Icons.bookmark_outline),
          label: const Text('Salvar e continuar depois'),
        ),
      ],
    );
  }

  Widget map() {
    final scores = [...s.scores]
      ..sort((a, b) => (b.score ?? -1).compareTo(a.score ?? -1));
    final liked = scores
        .where((f) => (f.score ?? 50) > 50)
        .map((f) => f.family)
        .take(3)
        .join(', ');
    final disliked = scores
        .where((f) => (f.score ?? 50) < 50)
        .map((f) => f.family)
        .join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          'Afinidades em construção',
          'Seu mapa olfativo',
          'Sem resposta significa sem dados. Cada resposta traz uma pista.',
        ),
        resetButton(),
        Text(
          '${s.mode == QuestionnaireMode.quick ? 'Resultado rápido' : 'Resultado completo'} · ${s.ratedCount} notas · ${s.unknownCount} cheiros desconhecidos fora do cálculo',
        ),
        if (s.ratedCount == 0)
          const Text(
            'Seu mapa ainda está em branco. Comece avaliando alguns cheiros.',
          ),
        if (liked.isNotEmpty) Text('Maiores afinidades: $liked'),
        if (disliked.isNotEmpty) Text('Menores afinidades: $disliked'),
        const SizedBox(height: 16),
        FamilyChart(scores: s.scores),
        const SizedBox(height: 12),
        if (s.ratedCount > 0)
          FilledButton.tonalIcon(
            onPressed: () => Scrollable.ensureVisible(
              perfumeSection.currentContext!,
              duration: const Duration(milliseconds: 350),
            ),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Ver meus 20 perfumes'),
          ),
        const SizedBox(height: 16),
        Text(
          'Evidências por família',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        for (final f in scores)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          f.family,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        f.score == null
                            ? 'Sem dados'
                            : '${decimal(f.score!)} / 100',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: (f.score ?? 0) / 100,
                    minHeight: 9,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${f.evidence} evidências • cobertura ${(f.coverage * 100).round()}% • confiança ${(f.confidence * 100).round()}%',
                  ),
                ],
              ),
            ),
          ),
        const Text(
          'Confiança indica evidências e cobertura, não probabilidade. Método heurístico sem validação científica.',
        ),
        PerfumeRanking(
          key: perfumeSection,
          matches: s.perfumeRanking,
          catalogSize: s.perfumes.length,
          ratedCount: s.ratedCount,
        ),
      ],
    );
  }

  Widget discoveries() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'Novas possibilidades',
        'Seu próximo encontro',
        s.ratedCount < 8
            ? 'Sugestões exploratórias, com baixa confiança. Avalie ao menos 8 cheiros para ampliar as evidências.'
            : 'Cheiros ainda não avaliados, ordenados por afinidade estimada.',
      ),
      if (s.suggestions.isEmpty)
        const Text('Você avaliou todo o catálogo. Consulte seu mapa.'),
      for (final r in s.suggestions.take(12))
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OdorCard(
              odor: r.odor,
              value: null,
              onUnknown: () => action(() => s.markUnknown(r.odor.id)),
              onChanged: (v) => action(() => s.setRating(r.odor.id, v)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              child: Text(
                r.prediction == null
                    ? 'Explore este cheiro: ainda não temos dados para estimar afinidade.'
                    : 'Afinidade estimada ${decimal(r.prediction!)} / 10 • confiança ${(r.confidence * 100).round()}%${r.reasons.isEmpty ? '\nSuas avaliações relacionadas sugerem menor afinidade ou neutralidade.' : '\nVocê gosta de ${r.reasons.join(' e ')}.'}',
              ),
            ),
          ],
        ),
    ],
  );
  Future<void> shareBytes(Uint8List bytes, String name, String mime) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mime)],
        fileNameOverrides: [name],
        sharePositionOrigin: box == null
            ? const Rect.fromLTWH(0, 0, 1, 1)
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Widget report() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'Para guardar e compartilhar',
        'Meu relatório',
        'Seu mapa, suas avaliações e novas descobertas. Algoritmo 1.0.0.',
      ),
      Text(
        '${s.ratedCount} notas nesta versão • ${s.unknownCount} cheiros desconhecidos • catálogo v${s.catalogVersion}',
      ),
      FamilyChart(scores: s.scores),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: () => action(() async {
          await Printing.sharePdf(
            bytes: await createReport(s),
            filename: 'meu-dna-olfativo.pdf',
          );
        }),
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: const Text('Exportar e compartilhar PDF'),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => action(
          () => shareBytes(
            Uint8List.fromList(utf8.encode(s.backup())),
            'dna-olfativo.json',
            'application/json',
          ),
        ),
        icon: const Icon(Icons.data_object),
        label: const Text('Exportar JSON / backup'),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => action(
          () => shareBytes(
            Uint8List.fromList(utf8.encode(s.csv())),
            'dna-olfativo.csv',
            'text/csv',
          ),
        ),
        icon: const Icon(Icons.table_chart_outlined),
        label: const Text('Exportar CSV'),
      ),
      PerfumeRanking(
        matches: s.perfumeRanking,
        catalogSize: s.perfumes.length,
        ratedCount: s.ratedCount,
      ),
    ],
  );
  Widget settings() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'Do seu jeito',
        'Configurações',
        'Você tem o controle das suas respostas.',
      ),
      DropdownButtonFormField<ThemeMode>(
        initialValue: widget.mode,
        decoration: const InputDecoration(labelText: 'Aparência'),
        items: const [
          DropdownMenuItem(
            value: ThemeMode.system,
            child: Text('Seguir sistema'),
          ),
          DropdownMenuItem(value: ThemeMode.light, child: Text('Claro')),
          DropdownMenuItem(value: ThemeMode.dark, child: Text('Escuro')),
        ],
        onChanged: (m) {
          if (m != null) widget.onTheme(m);
        },
      ),
      const SizedBox(height: 24),
      OutlinedButton(
        onPressed: () => action(() async {
          final file = await openFile(
            acceptedTypeGroups: [
              const XTypeGroup(
                label: 'Backup JSON',
                extensions: ['json'],
                uniformTypeIdentifiers: ['public.json'],
              ),
            ],
          );
          if (file == null) return;
          final text = await file.readAsString();
          s.decodeBackup(text);
          if (await confirm(
            'Importar backup?',
            'As respostas atuais serão substituídas pelas do backup.',
          )) {
            await s.importBackup(text);
          }
        }),
        child: const Text('Importar backup JSON'),
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: resetting ? null : () => action(resetResearch),
        icon: const Icon(Icons.delete_outline),
        label: const Text('Limpar tudo'),
      ),
      const Divider(height: 40),
      const Text(
        'Privacidade e método',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),
      const Text(
        'Sem login, anúncios ou envio de respostas a servidores. Os dados ficam neste aparelho. Exportações são compartilhadas somente por sua escolha.\n\nO mapa usa a média ponderada das notas centradas em 5. Notas em branco não entram no cálculo. Confiança depende de evidências e cobertura. Recomendações excluem cheiros já avaliados. Os pesos e o método são heurísticos, sem validação científica.\n\nCatálogo inicial: 157 cheiros da planilha fornecida. Atualizações futuras podem editar os itens mantendo os IDs para preservar suas respostas.',
      ),
    ],
  );
}

class OdorCard extends StatelessWidget {
  final Odor odor;
  final double? value;
  final ValueChanged<double?> onChanged;
  final bool unknown;
  final VoidCallback? onUnknown;
  const OdorCard({
    super.key,
    required this.odor,
    required this.value,
    required this.onChanged,
    this.unknown = false,
    this.onUnknown,
  });
  @override
  Widget build(BuildContext c) => Card(
    margin: const EdgeInsets.symmetric(vertical: 7),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(odor.name, style: Theme.of(c).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            unknown
                ? 'Não sei o cheiro · fora dos cálculos'
                : value == null
                ? 'Não avaliei'
                : 'Nota ${decimal(value!)}',
            style: TextStyle(color: Theme.of(c).colorScheme.primary),
          ),
          Slider(
            value: value ?? 5,
            min: 0,
            max: 10,
            divisions: 20,
            label: value == null ? 'Sem nota' : decimal(value!),
            activeColor: value == null ? Theme.of(c).colorScheme.outline : null,
            semanticFormatterCallback: (v) => value == null
                ? '${odor.name}, ${unknown ? 'cheiro desconhecido' : 'não avaliado'}. Ajuste para atribuir uma nota.'
                : '${odor.name}, nota ${decimal(v)} de 10',
            onChanged: onChanged,
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('Detesto · 0'), Text('Adoro · 10')],
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              IconButton(
                tooltip: 'Diminuir nota de ${odor.name} em 0,5',
                onPressed: value == 0
                    ? null
                    : () => onChanged(((value ?? 5) - 0.5).clamp(0, 10)),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              IconButton(
                tooltip: 'Aumentar nota de ${odor.name} em 0,5',
                onPressed: value == 10
                    ? null
                    : () => onChanged(((value ?? 5) + 0.5).clamp(0, 10)),
                icon: const Icon(Icons.add_circle_outline),
              ),
              TextButton(
                onPressed: value == null && !unknown
                    ? null
                    : () => onChanged(null),
                child: Text(unknown ? 'Limpar resposta' : 'Limpar nota'),
              ),
              if (value == null)
                TextButton(
                  onPressed: () => onChanged(5),
                  child: const Text('Avaliar com 5'),
                ),
              if (onUnknown != null)
                TextButton.icon(
                  onPressed: unknown ? null : onUnknown,
                  icon: Icon(
                    unknown ? Icons.check_circle_outline : Icons.help_outline,
                  ),
                  label: const Text('Não sei o cheiro'),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
