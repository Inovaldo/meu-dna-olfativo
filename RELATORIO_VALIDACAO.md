# Validação — atualização 1.3.0+5

Área **Só por curiosidade** adicionada, com acesso pelo botão **Explorar os 150 perfumes** na tela inicial e pelo ícone de livro na barra superior.

- Lista completa dos 150 perfumes, em ordem alfabética, sem exigir questionário respondido.
- Busca por perfume, marca e concentração, insensível a acentos; filtros combináveis por marca e presença de família olfativa; contagem de resultados e limpeza de filtros.
- Cartões com marca, concentração, resumo e famílias principais ilustradas. Detalhe com todas as famílias classificadas de peso positivo, níveis editoriais e fontes consultáveis.
- Navegar pelo catálogo não altera as respostas, o mapa nem o ranking.
- **33 testes passaram**, incluindo navegação pelo último dos 150 itens, busca durante digitação sem perda de foco, filtros e retorno sem modificar a pesquisa: `artifacts/tests-v1.3.log`.
- **Análise sem problemas**: `artifacts/analyze-v1.3.log`.
- Capturas reais de widgets Flutter revisadas visualmente: `artifacts/screenshots/07-catalogo-perfumes.png` e `08-perfil-perfume.png`.
- Build Android debug concluído em 15,9 segundos. APK de testes: `artifacts/apks/meu-dna-olfativo-1.3.0-teste.apk`, versão 1.3.0, build 5. Assinatura Android Debug e pacote conferidos. Tamanho e hash em `artifacts/build-manifest-v1.3.json`.
- Build web concluído em 48,0 segundos, com aviso conhecido do dry run Wasm na dependência image. Foi produzido build JavaScript.

A curadoria olfativa continua editorial: destaques não indicam percentuais de ingredientes ou intensidade garantida na pele. Nenhuma nova pesquisa de fragrâncias foi necessária; esta área expõe o catálogo existente e suas fontes. Não houve teste em aparelho físico; nenhum IPA ou nova release de produção foi gerado nesta atualização.

---

## Histórico de validação
# Validação — atualização 1.2.1+4

Botão **Resetar toda a pesquisa** adicionado no questionário e nos resultados, com ícone de reiniciar na barra superior. Confirmação obrigatória. Cancelar mantém os dados. Confirmar apaga todas as notas e respostas desconhecidas das duas versões, limpa páginas salvas (atuais e legadas), busca e filtros; zera o mapa e o ranking e retorna à tela inicial. A limpeza permanece após reabrir o armazenamento.

- **28 testes passaram**: `artifacts/tests-v1.2.1.log`, incluindo testes de reset persistido, dados fora da versão ativa, cancelamento e reinício da navegação sem filtros antigos.
- **Análise sem problemas**: `artifacts/analyze-v1.2.1.log`.
- **Build Android debug real concluído** em 14,2 segundos: `artifacts/android-debug-v1.2.1.log`.
- APK de testes entregue: `artifacts/apks/meu-dna-olfativo-1.2.1-teste.apk`, versão **1.2.1**, build **4**, pacote `com.suaempresa.dnaolfativo`.
- Assinatura verificada com apksigner: **Android Debug**, mesmo certificado da versão anterior. Registro: `artifacts/apk-debug-signature-v1.2.1.log`.
- Tamanho e SHA-256 em `artifacts/build-manifest-v1.2.1.json`.
- Capturas de widgets atualizadas em `artifacts/screenshots`, incluindo o botão visível no questionário. Não houve teste em aparelho físico.

Este APK é para testes. Não foi gerada nova release de produção nesta atualização; a release anterior continua sem assinatura privada. Nenhum IPA foi gerado.

---

## Histórico da validação anterior
# Validação — atualização 1.2.0+3

Data: 15/10/2026, America/Sao_Paulo.

## Ranking internacional entregue

- Catálogo offline real de 150 perfumes de 30 marcas, cada item identificado por ID, marca, nome e concentração. A base tem as 12 famílias com pesos editoriais 0–3, resumo olfativo e fontes com data de consulta.
- Pesquisa de descrições por produto e conferência da concentração. Preferência por marcas/fabricantes (136 referências); 14 referências complementares de varejistas. Referências completas em `FONTES_PERFUMES.md`; versão estruturada em `assets/perfumes_150.json`.
- Curadoria de fragrâncias conhecidas; não se alega ranking estatístico de vendas, estoque local ou pesquisa automática atualizada ao vivo. A classificação por famílias é interpretação editorial, não fórmula dos fabricantes.
- O resultado termina com 20 sugestões e possui um atalho após o gráfico. Cada cartão mostra posição, marca, concentração, índice de afinidade, confiança, justificativa, famílias de atenção e fonte consultável.
- Preferências e rejeições entram no cálculo. Confiança atenua extrapolação; famílias sem respostas não são tratadas como aversão. Sem respostas válidas não se inventa ranking; com menos de 8 notas o ranking é exploratório.
- Os índices não são probabilidades nem avaliações de qualidade. Empates são resolvidos de forma determinística. Não há ordenação patrocinada ou filtro obrigatório por gênero.
- Funciona nos questionários rápido e completo, respeitando o perfil da versão ativa. “Não sei o cheiro” continua sem entrar no cálculo.
- Ranking incluído no PDF e no JSON exportado, com versões independentes do algoritmo e do catálogo de perfumes. Importar backup recalcula recomendações a partir das notas.
- Nenhuma requisição de rede é feita ao responder ou gerar ranking. Só abrir uma fonte externa depende de internet.

## Verificações reais

- `flutter test --no-pub`: **26 testes passaram**. Log: `artifacts/tests-v1.2.log`.
- Os novos testes cobrem a integridade dos 150 perfumes, 30 marcas, IDs e versões únicas, famílias e fontes; ranking de 20 sem duplicação; ausência de ranking sem dados; alteração real da ordem com o perfil; rejeições; confiança; famílias desconhecidas; neutralidade; desempate determinístico; troca de questionário; JSON e PDF; navegação pelo atalho e cartões com fontes.
- `flutter analyze --no-pub`: **No issues found**. Log: `artifacts/analyze-v1.2.log`.
- A captura do ranking foi repetida depois de remover o banner de debug do harness de captura: passou. Log: `artifacts/perfume-screenshot-v1.2.log`. O aplicativo já desativa esse banner.
- `artifacts/screenshots/06-ranking-perfumes.png`: captura real de widgets Flutter, viewport 412×1200, com notas sintéticas. Revisada visualmente; não é captura de aparelho físico.
- `artifacts/relatorio-perfumes.pdf`: PDF gerado realmente, 4 páginas. Extração independente confirmou a seção, a posição 20 e 20 fontes. Página do ranking renderizada com Poppler e revisada visualmente em `artifacts/relatorio-perfumes-preview.png`.
- `flutter build web --release --no-web-resources-cdn`: **concluído**, 72,1 segundos. Versão 1.2.0+3 confirmada pelo endpoint local `version.json`. Log: `artifacts/web-build-v1.2.log`.
- O dry run Wasm continua avisando sobre a dependência image; o build JavaScript concluiu. Não se alega build Wasm.
- `flutter build apk --release --no-pub`: **concluído**, 88,7 segundos. Continua sem assinatura privada para distribuição. Log: `artifacts/android-release-v1.2.log`.
- `flutter build apk --debug --no-pub`: **concluído**, 26,7 segundos. APK de testes em `build/app/outputs/flutter-apk/app-debug.apk`, versão 1.2.0+3 e assinatura Android Debug conferidas. Log: `artifacts/android-debug-v1.2.log`.
- Os dois catálogos embarcados foram conferidos byte a byte contra os assets; o APK contém os 150 perfumes e preserva o JSON original dos 157 cheiros. Tamanhos e SHA-256 atualizados em `artifacts/build-manifest.json`.

## Limites

A prévia está em http://127.0.0.1:8765/?v=1.2.0 neste computador. Recarregue sem cache (Ctrl+F5) para atualizar uma aba antiga. Nada foi publicado no GitHub.

Persistência e interface foram verificadas com testes Flutter. Não houve execução em aparelho físico nem teste nativo completo dos share sheets. Abrir fontes usa o navegador externo e tem tratamento de falha com o endereço copiável.

Perfis e confiança são heurísticos, sem validação científica. Antes de comprar, a pessoa deve experimentar o perfume. A disponibilidade e eventuais reformulações precisam de conferência no mercado; não são inferidas pelo aplicativo.

Release de distribuição depende de identidade definitiva e keystore privada. Não há chaves ou senhas no projeto. Nenhum IPA foi gerado neste ambiente Windows; iOS exige macOS, Xcode e provisionamento Apple, conforme README.


