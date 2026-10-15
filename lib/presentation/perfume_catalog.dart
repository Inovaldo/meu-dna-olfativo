import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/perfume.dart';
import 'family_chart.dart';

String _searchText(String text) {
  const accents = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const plain = 'aaaaaeeeeiiiiooooouuuucn';
  var result = text.toLowerCase();
  for (var i = 0; i < accents.length; i++) {
    result = result.replaceAll(accents[i], plain[i]);
  }
  return result.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

class PerfumeCatalogPage extends StatefulWidget {
  final List<Perfume> perfumes;
  final List<String> families;
  const PerfumeCatalogPage({
    super.key,
    required this.perfumes,
    required this.families,
  });
  @override
  State<PerfumeCatalogPage> createState() => _PerfumeCatalogPageState();
}

class _PerfumeCatalogPageState extends State<PerfumeCatalogPage> {
  final query = TextEditingController();
  String? family, brand;
  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  void clearFilters() => setState(() {
    query.clear();
    family = null;
    brand = null;
  });
  @override
  Widget build(BuildContext context) {
    final terms = _searchText(query.text).split(' ').where((t) => t.isNotEmpty);
    final brands = widget.perfumes.map((p) => p.brand).toSet().toList()..sort();
    final matches =
        widget.perfumes
            .where(
              (p) =>
                  (family == null || (p.weights[family] ?? 0) > 0) &&
                  (brand == null || p.brand == brand) &&
                  terms.every(
                    (term) => _searchText(
                      '${p.brand} ${p.name} ${p.concentration}',
                    ).contains(term),
                  ),
            )
            .toList()
          ..sort(
            (a, b) => _searchText(
              '${a.brand} ${a.name} ${a.concentration}',
            ).compareTo(_searchText('${b.brand} ${b.name} ${b.concentration}')),
          );
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo de perfumes')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: matches.length + 1,
            itemBuilder: (context, index) {
              if (index > 0) return _CatalogCard(perfume: matches[index - 1]);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Só por curiosidade',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Explore os ${widget.perfumes.length} perfumes',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Conheça as fragrâncias e suas famílias olfativas, mesmo sem responder à pesquisa. Aqui a ordem é alfabética; explorar não altera suas respostas.',
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: query,
                    decoration: InputDecoration(
                      labelText: 'Buscar perfume ou marca',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpar busca',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(query.clear),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('family-$family'),
                    initialValue: family,
                    isExpanded: true,
                    hint: const Text('Todas as famílias'),
                    decoration: const InputDecoration(
                      labelText: 'Família olfativa',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todas as famílias'),
                      ),
                      for (final f in widget.families)
                        DropdownMenuItem(value: f, child: Text(f)),
                    ],
                    onChanged: (f) => setState(() => family = f),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey('brand-$brand'),
                    initialValue: brand,
                    isExpanded: true,
                    hint: const Text('Todas as marcas'),
                    decoration: const InputDecoration(
                      labelText: 'Marca',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Todas as marcas'),
                      ),
                      for (final b in brands)
                        DropdownMenuItem(value: b, child: Text(b)),
                    ],
                    onChanged: (b) => setState(() => brand = b),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${matches.length} de ${widget.perfumes.length} perfumes',
                      ),
                      if (family != null ||
                          brand != null ||
                          query.text.isNotEmpty)
                        TextButton(
                          onPressed: clearFilters,
                          child: const Text('Limpar filtros'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Os destaques são uma leitura editorial das descrições das marcas. Não representam a fórmula nem a concentração de ingredientes.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  if (matches.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Nenhum perfume encontrado. Tente outro nome ou limpe os filtros.',
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  final Perfume perfume;
  const _CatalogCard({required this.perfume});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PerfumeDetailPage(perfume: perfume),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              perfume.brand,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(perfume.name, style: Theme.of(context).textTheme.titleLarge),
            Text(perfume.concentration),
            const SizedBox(height: 12),
            Text(perfume.profileSummary),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in perfume.mainFamilies)
                  Chip(
                    avatar: Icon(
                      familyVisuals[f]!.$2,
                      size: 18,
                      color: familyVisuals[f]!.$3,
                    ),
                    label: Text(f),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Expanded(child: Text('Ver perfil completo e fontes')),
                Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class PerfumeDetailPage extends StatelessWidget {
  final Perfume perfume;
  const PerfumeDetailPage({super.key, required this.perfume});
  Future<void> openSource(BuildContext context, String url) async {
    try {
      if (!await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('Fonte indisponível');
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('Abra a fonte no navegador: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = perfume.weights.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        return c == 0 ? a.key.compareTo(b.key) : c;
      });
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil do perfume')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                perfume.brand,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                perfume.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(perfume.concentration),
              const SizedBox(height: 20),
              Text(
                perfume.profileSummary,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Text(
                'Famílias olfativas em destaque',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final entry in entries)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              familyVisuals[entry.key]!.$2,
                              color: familyVisuals[entry.key]!.$3,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${entry.key} · ${familyVisuals[entry.key]!.$1}',
                              ),
                            ),
                            Text(
                              entry.value >= 3
                                  ? 'Marcante'
                                  : entry.value >= 2
                                  ? 'Presente'
                                  : 'Toque suave',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: entry.value / 3,
                          color: familyVisuals[entry.key]!.$3,
                          semanticsLabel:
                              '${entry.key}: ${entry.value >= 3
                                  ? 'marcante'
                                  : entry.value >= 2
                                  ? 'presente'
                                  : 'toque suave'}',
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'Marcante, presente e toque suave indicam apenas o destaque atribuído na curadoria. Não são percentuais da fórmula nem garantia de intensidade na sua pele.',
              ),
              const SizedBox(height: 24),
              Text(
                'Fontes da descrição',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final source in perfume.sources)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(source.title),
                      TextButton.icon(
                        onPressed: () => openSource(context, source.url),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Abrir fonte no navegador'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
