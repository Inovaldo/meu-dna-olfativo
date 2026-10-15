import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/perfume.dart';

class PerfumeRanking extends StatelessWidget {
  final List<PerfumeMatch> matches;
  final int catalogSize, ratedCount;
  const PerfumeRanking({
    super.key,
    required this.matches,
    required this.catalogSize,
    required this.ratedCount,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 28),
      Text(
        '20 perfumes para experimentar',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 10),
      Text(
        'Uma seleção personalizada a partir de $catalogSize perfumes internacionais. Comparamos o perfil de cada versão com suas afinidades pelas 12 famílias.',
      ),
      const SizedBox(height: 10),
      const Text(
        'O índice de afinidade não é uma probabilidade de gostar. Prefira experimentar na pele antes de escolher.',
      ),
      const SizedBox(height: 12),
      if (matches.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Avalie alguns cheiros para formar seu ranking. “Não sei o cheiro” não indica gosto e não gera recomendações personalizadas.',
            ),
          ),
        )
      else ...[
        if (ratedCount < 8)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Ranking exploratório: ainda há poucas respostas. Com pelo menos 8 cheiros avaliados, teremos mais pistas para comparar.',
              ),
            ),
          ),
        for (var i = 0; i < matches.length; i++)
          _PerfumeCard(position: i + 1, match: matches[i]),
      ],
      const SizedBox(height: 10),
      const Text(
        'Base curada, sem patrocínio ou filtro de gênero. As famílias e seus pesos são estimativas editoriais a partir das descrições citadas. Não verificamos preço, estoque ou reformulações em tempo real.',
      ),
    ],
  );
}

class _PerfumeCard extends StatelessWidget {
  final int position;
  final PerfumeMatch match;
  const _PerfumeCard({required this.position, required this.match});

  Future<void> openSource(BuildContext context, String url) async {
    try {
      if (!await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      )) {
        throw StateError('Não foi possível abrir a fonte.');
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
    final p = match.perfume;
    final confidence = match.confidence < .25
        ? 'baixa'
        : match.confidence < .55
        ? 'moderada'
        : 'alta';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 19, child: Text('$position')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.brand,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        p.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(p.concentration),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              match.score == null
                  ? 'Exploração · ainda sem comparação suficiente'
                  : 'Afinidade estimada: ${match.score!.toStringAsFixed(1).replaceAll('.', ',')} / 100',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              'Confiança $confidence · ${(match.coverage * 100).round()}% do perfil olfativo relacionado às suas respostas',
            ),
            const SizedBox(height: 12),
            Text(match.explanation),
            if (match.negativeFamilies.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Pontos de atenção: ${match.negativeFamilies.join(' e ')} aparecem no perfume e tiveram menor afinidade nas suas respostas.',
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in p.mainFamilies)
                  Chip(label: Text(f), visualDensity: VisualDensity.compact),
              ],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Perfil e fonte'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(p.profileSummary),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Leitura olfativa editorial; não representa a fórmula ou proporção de ingredientes.',
                ),
                for (final source in p.sources)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => openSource(context, source.url),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(
                        '${source.type == 'brand' ? 'Marca' : 'Catálogo do varejista'} · fonte consultada em 15/10/2026',
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
