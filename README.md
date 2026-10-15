# Teste pelo navegador

Acesse **https://inovaldo.github.io/meu-dna-olfativo/** no iPhone, Android ou computador. Não precisa instalar o aplicativo nem criar conta. As respostas ficam no navegador de cada participante; não são enviadas automaticamente ao organizador. Para compartilhar os resultados, use a exportação no relatório.

O código-fonte está em https://github.com/Inovaldo/meu-dna-olfativo. A branch `main` contém o projeto Flutter; `gh-pages` contém apenas o site compilado. Arquivos de trabalho, backups de usuários, APKs e chaves privadas não entram no repositório.

Para reconstruir o site para esta URL:

```powershell
flutter pub get
flutter build web --release --no-web-resources-cdn --base-href /meu-dna-olfativo/ --output build/github-pages
```

A pasta `build/github-pages` é o conteúdo da branch `gh-pages`, com um arquivo vazio `.nojekyll`. Atualizar somente `main` não republica o site: é necessário gerar e enviar também o novo build para `gh-pages`.

---
# Meu DNA Olfativo

Aplicativo Flutter em português do Brasil, sem servidor e sem login. Usa os 157 cheiros reais fornecidos e 12 famílias. O JSON original é preservado na raiz e copiado integralmente para `assets/odores_157.json`. A planilha original não foi alterada. `artifacts/source-validation.json` documenta a conferência de todos os nomes contra o Excel.

## Executar e validar

Requer Flutter stable com Dart >=3.11.4. Ambiente utilizado: Flutter 3.41.6 / Dart 3.11.4.

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
# Ou, com dispositivo Android conectado e depuração USB habilitada:
flutter run -d <device-id>
flutter build web --release --no-web-resources-cdn
```

O aplicativo móvel funciona offline desde a primeira abertura: catálogo e fonte do relatório são assets locais. A versão web serve para revisão, precisa ser servida por HTTP e não promete instalação PWA ou primeiro carregamento offline. O navegador conserva respostas por origem; trocar porta/domínio muda o armazenamento.

## Uso

- Começar/Continuar abre cartões paginados de 12 cheiros (última página com 1), busca e filtros de avaliação. Não há termos de matérias-primas no questionário.
- Slider 0–10 com 20 divisões, botões -0,5/+0,5 e avaliação explícita com 5. Renderizar um slider sem resposta nunca grava uma nota. “Limpar nota” volta a ausência, distinta de 0 e 5.
- Cada mudança salva automaticamente. “Salvar e continuar depois” registra a página; Continuar reabre esse ponto. Busca/filtro voltam ao padrão após reinício.
- Mapa mostra barras, afinidade, evidências, cobertura e confiança das 12 famílias. Sem dados é explicitamente identificado.
- Descobertas excluem todas as avaliações existentes. Antes de 8 respostas são exploratórias. As justificativas citam exemplos de cheiros avaliados positivamente com famílias em comum, sem alegar causalidade ou certeza.
- Relatório gera PDF multipágina com fonte local, JSON de backup e CSV. O sistema operacional apresenta opções de compartilhar/salvar; no navegador pode ser download. Importar JSON e limpar tudo pedem confirmação.
- Configurações oferecem tema claro/escuro/sistema, método e privacidade. A escolha de aparência vale para a sessão; as avaliações persistem.

## Arquitetura e armazenamento

`lib/domain/profile.dart`: modelos Odor, Rating, FamilyScore e Recommendation, cálculo determinístico sem Flutter, desempate por afinidade, confiança, menor representação da família principal entre respostas e nome.

`lib/data/profile_store.dart`: carrega assets, valida notas e backups, serializa respostas e datas, preserva IDs desconhecidos de versões futuras e publica mudanças com ChangeNotifier. `ListenableBuilder` é o estado reativo equivalente ao solicitado. A fila de gravações impede que salvamentos rápidos terminem fora de ordem; falhas aparecem na UI.

`lib/presentation/`: seis telas Material 3, componentes acessíveis e relatório. O arquivo `main.dart` inicializa o estado e trata falha de abertura sem apagar dados existentes.

Escolha de `shared_preferences`: volume pequeno (157 notas), sem banco consultável ou servidor. Salva um documento versionado por chave estável `profile_v1`, com timestamps UTC. Não é armazenamento criptografado e não garante recuperação após remoção do aplicativo; exporte backups. Não migrar por posição ou nome: os IDs são a identidade das respostas. Ao editar o catálogo, preserve IDs, incremente `version`, atualize asset e testes. Uma futura tela de edição de catálogo não faz parte desta versão.

PDF/printing geram e compartilham o relatório; share_plus compartilha JSON/CSV; file_selector usa o seletor nativo. Noto Sans e sua licença OFL estão em assets. `image: 4.5.4` foi fixado porque image 4.11.0 usava uma API ausente no archive 4.0.9 permitido por pdf 3.12.0 neste SDK. `pubspec.lock` conserva a resolução testada.

## Método v1.0.0

Só notas existentes entram nas somas. `s=(r-5)/5`; por família, `A=Σ(w*s)/Σw`, `score=50+50*A`; denominador zero resulta em null. Evidências contam respostas com peso positivo, incluindo notas 0 e 5. Cobertura é evidências/total de itens associados; confiança é `min(1,n/8)*sqrt(cobertura)`. Predição usa a média das afinidades ponderadas por peso e confiança, convertida para 0–10 e limitada aos extremos. Sem dados não se inventam preferências.

Pesos e algoritmo são heurísticos, sem validação científica. Confiança não representa probabilidade calibrada. Validação futura exige feedback real, incluindo casos em que a recomendação é rejeitada.

Backups JSON incluem schemaVersion, catalogVersion, algorithmVersion, data da exportação, notas com datas e scores. Na importação os scores são recalculados; campos derivados não são confiados. Importação substitui respostas somente após validação completa. CSV contém todas as notas (vazio=ausência) e scores; textos são escapados e UTF-8 com BOM facilita abertura no Excel.

## Android: assinatura e instalação privada

ID provisório: `com.suaempresa.dnaolfativo`. Nome: Meu DNA Olfativo. Ícone original geométrico em `assets/icon-original.png`. Não foram adicionadas permissões de contatos, localização ou armazenamento amplo.

Antes de distribuição, confirmar identificação final da empresa e configurar sua keystore privada. Não inserir chave ou senha no Git. Gere a chave em diretório privado, fora do projeto, com o keytool do JDK; use senhas interativas:

```powershell
keytool -genkeypair -v -keystore C:/private/dna-olfativo-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
Copy-Item android/key.properties.example android/key.properties
# Edite android/key.properties localmente com caminho, alias e senhas reais.
./tools/build_android_release.ps1
# Opcional:
./tools/build_android_release.ps1 -SplitPerAbi
```

`android/key.properties`, `.jks` e `.keystore` estão ignorados. A configuração Gradle usa credenciais privadas quando existem; não recorre à chave debug para release. Sem credenciais, `flutter build apk --release` tenta produzir binário **sem assinatura**, que não é pronto para instalação/distribuição. O script de distribuição exige as credenciais.

Com build assinado concluído, conferir assinatura com `apksigner verify --verbose <apk>` e instalar em aparelho real: `adb install -r build/app/outputs/flutter-apk/app-release.apk`. Pode enviar esse APK por arquivo/link; o usuário autoriza a instalação por aquela origem no Android. Atualizações exigem mesmo ID e mesma chave. Não publicar em loja.

Se licenças estiverem pendentes: execute `flutter doctor --android-licenses` e leia/aceite as licenças aplicáveis. O agente não aceitou contratos em seu nome.

## iOS: macOS obrigatório

Abrir `ios/Runner.xcworkspace` no Xcode em um Mac, definir o bundle ID final e a equipe Apple, configurar certificados e perfis e revisar os deployment targets exigidos pelos plugins. Executar `flutter pub get`, `flutter build ipa --release` e validar o Archive/Export no Xcode.

Ad Hoc exige dispositivos registrados e provisionamento apropriado. TestFlight usa App Store Connect e os requisitos de teste da Apple, sem publicação pública. Não é possível instalar APK no iPhone. Este ambiente Windows não gera nem assina IPA; nenhum IPA é prometido.

## Evidências

`artifacts/tests.log`, `artifacts/analyze.log` e logs de build registram os comandos reais. `RELATORIO_VALIDACAO.md` resume os resultados e limites. Capturas em `artifacts/screenshots` são renderizações reais de widgets Flutter em viewport móvel de 412×915, feitas por testes; não são capturas de um celular físico. O PDF de validação contém dados sintéticos de teste e não preferências de cliente.

## APK para teste técnico

Foi compilado também `build/app/outputs/flutter-apk/app-debug.apk` e sua assinatura Android Debug foi verificada. Pode ser instalado para avaliação técnica com `adb install -r build/app/outputs/flutter-apk/app-debug.apk` ou abrindo o arquivo em Android compatível. É maior e não substitui a release assinada com a chave definitiva. Não houve instalação em aparelho nesta sessão. Um APK assinado com a chave final não atualiza a instalação debug de mesma identidade; exporte o backup antes de desinstalar a versão de teste.

## Atualização 1.1 — rápido, completo e cheiros desconhecidos

Na tela inicial é possível escolher **Rápido · 24 cheiros** ou **Completo · 157 cheiros** antes de Começar/Continuar. A versão rápida tem exatamente dois exemplos da família principal de cada uma das 12 famílias, selecionados no catálogo original por familiaridade cotidiana:

| Família | Exemplos do questionário rápido |
| --- | --- |
| Amadeirado | madeira recém-cortada; lápis apontado |
| Ambarado | incenso suave; vela perfumada quente |
| Almiscarado | sabonete branco; roupa recém-lavada |
| Floral | rosa fresca; buquê de flores |
| Gourmand | café passado; chocolate ao leite |
| Verde | capim recém-cortado; folhas amassadas |
| Cítrico | limão espremido; casca de laranja |
| Aquático | cheiro de chuva; brisa do mar |
| Aromático | chá de camomila; chá de hortelã |
| Frutado | morango maduro; abacaxi |
| Especiado | pimenta-do-reino; canela em pau |
| Terroso | terra molhada; terra de vaso |

A seleção é uma curadoria de exemplos familiares, não uma garantia de que toda pessoa já conheça cada cheiro. IDs e pesos do JSON não mudaram. A definição testada está em `lib/domain/questionnaire.dart`.

As versões compartilham respostas por ID e não apagam notas ao alternar. O mapa e o relatório usam somente as notas dos itens da versão escolhida. Notas de outros itens continuam armazenadas para quando a versão completa for retomada. A confiança mantém a cobertura do catálogo completo como referência, para não inflar a confiança do teste rápido.

**Não sei o cheiro** é um estado explícito, salvo com data, distinto de nota 0, nota 5 e ausência de resposta. Marcar essa opção remove eventual nota anterior. Não entra em médias, evidências, afinidades ou confiança como resposta avaliada, nem reaparece nas descobertas. Entra apenas no progresso de perguntas respondidas, separado da contagem de notas. Pode-se limpar a resposta ou dar uma nota posteriormente. Limpar tudo apaga notas e desconhecidos.

Backups antigos continuam funcionando. JSON novo inclui `questionnaireMode` e `unknownOdors`; CSV inclui estado explícito e modo. Importação valida conflitos entre nota e desconhecido antes de substituir os dados. O progresso de página é salvo separadamente por versão.

O botão **Concluir e ver meu resultado** aparece na última página; também é possível ver o resultado parcial. O novo gráfico ilustrado usa ícones, cores e barras de 0 a 100 para todas as famílias. A marca em 50 é a neutralidade; famílias sem notas ficam como **Sem dados**, sem inferir rejeição. Os valores são afinidades independentes e não percentuais que somam 100%. O gráfico também foi incorporado ao relatório e ao PDF.

Logs desta atualização usam o sufixo `v1.1` em `artifacts/`. A captura `artifacts/screenshots/05-resultado-rapido.png` usa notas sintéticas de teste e mostra as 12 famílias.

## Atualização 1.2 — ranking de perfumes internacionais

O resultado e o relatório agora terminam com **20 perfumes para experimentar**, escolhidos de um catálogo local de **150 perfumes e 30 marcas**. Um atalho depois do gráfico leva diretamente ao ranking. O aplicativo identifica a concentração (Eau de Toilette, Eau de Parfum, Cologne etc.), explica as famílias que combinam com o perfil e destaca as famílias presentes no perfume que tiveram notas negativas. Não há filtro obrigatório por gênero, anúncios, links de afiliados ou ordenação patrocinada.

O catálogo é uma curadoria de fragrâncias conhecidas, não uma lista estatística dos 150 mais vendidos. A pesquisa foi feita em 15/10/2026, preferindo descrições das marcas e complementando com catálogos comerciais quando necessário. Há **136 referências de marcas/fabricantes e 14 de varejistas**. As fontes de cada versão estão no próprio aplicativo, em `assets/perfumes_150.json` e em `FONTES_PERFUMES.md`. Os pesos de 0 a 3 são interpretações editoriais das descrições, não medidas fornecidas pelas marcas nem proporções de ingredientes. Não há consulta de estoque, preço ou reformulação em tempo real.

O funcionamento continua offline: não é feita pesquisa de rede quando alguém responde. Só o botão da fonte abre o navegador, por escolha do usuário. PDFs e JSON incluem o ranking; CSV mantém as notas, estados das respostas e scores das famílias.

### Método de perfumes v1.0.0

Para cada perfume, D é a soma de todos os seus pesos. Para cada família com respostas, usamos a afinidade centrada A do mapa e sua confiança c. Calculamos:

- sinal = Σ(w × A × c), apenas para famílias conhecidas;
- índice de afinidade = clamp(50 + 50 × sinal / D, 0, 100);
- confiança agregada = Σ(w × c) / D;
- proporção relacionada observada = Σ(w de famílias conhecidas) / D.

Manter todo o peso D no denominador atenua a extrapolação quando só uma parte do perfume foi observada. Rejeições reduzem o índice; informações ausentes não viram aversão. Afinidades positivas e negativas geram as justificativas e os pontos de atenção. O índice não é uma probabilidade de gostar nem uma nota de qualidade do perfume.

Desempate determinístico: índice, confiança, proporção observada, marca, nome, concentração e ID. São mostrados 20 sem duplicação. Se não há evidências para um perfume, o índice é null e ele aparece apenas como exploração depois das comparações disponíveis. Se não há notas válidas no questionário ativo, nenhum ranking pessoal é inventado. Com menos de 8 notas, a seção é explicitamente exploratória. A confiança textual usa os intervalos baixa <0,25, moderada <0,55 e alta a partir de 0,55; esses limiares também são heurísticos.

`lib/domain/perfume.dart` contém o motor puro. `lib/presentation/perfume_ranking.dart` apresenta os resultados e as fontes. `tools/perfume_sources.json` registra as referências conferidas; `tools/build_perfume_catalog.py` gera o asset e o documento de fontes. Preserve os IDs existentes ao atualizar a curadoria e incremente a versão do catálogo quando alterar perfis.

Os backups recebem `perfumeAlgorithmVersion`, `perfumeCatalogVersion` e `perfumeRecommendations`. Na importação, o ranking é recalculado a partir das notas, nunca aceito como uma verdade do arquivo importado.

Logs desta atualização: `artifacts/*v1.2.log`. A captura `artifacts/screenshots/06-ranking-perfumes.png` usa notas sintéticas. A versão do aplicativo é 1.2.0+3; a fórmula do mapa permanece v1.0.0 e o motor de perfumes tem sua própria versão v1.0.0.

## Atualização 1.2.1 — reset completo da pesquisa

Botão **Resetar toda a pesquisa** visível no questionário e nos resultados, além do ícone de reiniciar na barra superior de todas as telas. O comando **Limpar tudo** das configurações usa o mesmo fluxo.

O reset exige confirmação. Ao confirmar, apaga todas as notas das versões rápida e completa, respostas “Não sei o cheiro”, progresso e páginas salvas de ambas as versões (incluindo a chave antiga), busca e filtros da sessão. O mapa e o ranking ficam vazios e a pessoa volta ao início para escolher a versão e começar novamente. O modo inicial volta ao completo. Cancelar preserva tudo. O catálogo dos 157 cheiros e dos 150 perfumes não é apagado.

Versão Android: 1.2.1, build 4, mesmo ID provisório e mesma assinatura de desenvolvimento do APK anterior. Testes e logs desta atualização: `artifacts/tests-v1.2.1.log`, `artifacts/analyze-v1.2.1.log`, `artifacts/android-debug-v1.2.1.log` e `artifacts/web-build-v1.2.1.log`.

## Atualização 1.3 — catálogo “Só por curiosidade”

A tela inicial oferece **Explorar os 150 perfumes**. O ícone de livro **Catálogo de perfumes** na barra superior abre a mesma área a partir das demais telas. Não é preciso responder ao questionário.

O catálogo permite percorrer os 150 perfumes em ordem alfabética de marca e nome, buscar por nome/marca/concentração sem diferenciar acentos e combinar filtros de marca e família. O filtro de família inclui qualquer presença positiva atribuída na curadoria, inclusive toques suaves. A contagem mostra quantos itens correspondem à busca; **Limpar filtros** restaura a lista completa. A lista cria cartões sob demanda, permitindo navegar pelo acervo inteiro sem montar os 150 cartões de uma vez.

Os cartões destacam até três famílias com ícones e cores e mostram marca, nome, concentração e resumo. Tocar no cartão abre o perfil completo, com todas as famílias de peso positivo e seus níveis editoriais **Marcante**, **Presente** ou **Toque suave**, além das fontes consultáveis. Não são proporções de ingredientes nem avaliações do usuário.

A exploração funciona offline e não modifica notas, desconhecidos, perfil ou ranking. Abrir uma fonte externa depende de internet. Nenhum novo dado de perfume foi inventado para esta tela: ela usa o mesmo catálogo de 150 fragrâncias já pesquisado.

Implementação: `lib/presentation/perfume_catalog.dart`. Testes de navegação, pesquisa, foco de digitação, filtros combinados, chegada ao último item e não alteração da pesquisa em `test/perfume_catalog_test.dart`. Capturas revisadas: `artifacts/screenshots/07-catalogo-perfumes.png` e `08-perfil-perfume.png`.

Versão 1.3.0+5. Logs de testes, análise e builds usam o sufixo `v1.3`.

