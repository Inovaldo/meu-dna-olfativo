"""Build the offline perfume catalog from reviewed sources and editorial profiles.
W=wood, B=amber, M=musk, F=floral, G=gourmand, V=green, C=citrus,
A=aquatic, H=aromatic, R=fruity, S=spicy, T=earthy. 0..3 are editorial,
not brand measurements, ingredient concentrations, or a calibrated model.
"""
import json, pathlib, re
root = pathlib.Path(__file__).resolve().parents[1]
sources = json.loads((root/'tools/perfume_sources.json').read_text(encoding='utf8'))
# Five entries per brand, in source-file order. Short sensory paraphrases.
profiles = '''
B3 F2 W2 C2 T1|Laranja, flores e fundo amadeirado ambarado
W3 H2 B2 M1 C1|Madeiras, ervas e calor ambarado
F3 M2 B1 W1|Buquê floral, toque de talco e fundo quente
F3 R2 M2 C1|Flores delicadas, frutas e maciez de limpeza
C3 W2 M2 A1 H1|Cítricos frescos, cedro e maciez limpa
C2 B3 S2 H1 W1 G1|Cítricos, especiarias e baunilha quente
F3 R1 M1|Flores brancas e rosas com leve frescor frutado
F3 G2 W2 B1|Rosa, baunilha cremosa e madeira macia
W3 T2 S1 C1|Madeira seca, raízes e frescor discreto
G3 B3 F1 W1|Amêndoas, baunilha e flores envolventes
F3 H2 B2 G1 M1|Flores brancas, lavanda e baunilha
G3 F2 B2 W1|Café, baunilha e flores brancas
H3 W2 C2 R1|Ervas, madeira e frescor frutado
S3 W2 B1 F1|Especiarias macias, madeira e toque floral
R3 F2 W1 T1 M1|Frutas vermelhas, flores e fundo amadeirado
A3 C3 H1 W1|Brisa marinha, cítricos e ervas
A3 H2 W2 C1|Mar, ervas frescas e madeira
B2 W2 C1 H1 G1|Cítricos suaves e fundo amadeirado quente
R3 F2 B2 G1 W1|Frutas escuras, flores e baunilha
F3 C1 W1 M1|Flores brancas, cítricos e madeira suave
G3 F2 B2 T1|Doçura de confeitaria, flores e fundo terroso
F3 M2 R1 C1|Rosas, flores brancas e limpeza macia
F3 R2 B2 W1 G1|Rosa, frutas macias e baunilha ambarada
F3 R2 S1 M1|Flores frescas, frutas e toque de especiarias
G3 R2 F2 B2 W1|Baunilha doce, frutas e rosa escura
B3 G2 F1 C1 W1|Baunilha ambarada, flores e cítricos
B3 G2 H2 W1 F1|Baunilha, lavanda, madeira e flores
R3 G2 F2 B1 H1|Cereja doce, rosa e toque de chá
B3 C2 W2 G1 S1|Cítricos, baunilha e madeira quente
T3 W3 C2 H1|Raízes secas, madeira e cítricos
G3 F2 B2 W1|Flores brancas com doçura de amêndoas e cacau
R3 F3 G1 W1|Frutas vermelhas, rosa e baunilha suave
F3 M2 W1 C1|Flores frescas e maciez limpa
R3 F2 M1 W1|Frutas, flores e fundo macio
S3 G2 B2 W1 C1|Especiarias, cacau e fundo ambarado
S3 B2 W2 C1|Especiarias doces, cítricos e madeira quente
A3 C2 W1 H1|Mar, cítricos e frescor aromático
F3 G2 R2 W1|Flores brancas, mel e frutas
B3 G2 F1 A1|Baunilha salgada com flores e calor ambarado
R3 F2 W2 G1|Fruta tropical, flores e madeira cremosa
H3 G2 B2 M1|Lavanda, hortelã e baunilha macia
G3 R3 B2 H1|Pera doce, baunilha e frescor de lavanda
R3 W2 G2 C1|Coco, madeira macia e cítricos
G3 F2 T1 W1|Mel intenso, flores brancas e fundo terroso
F3 G2 B2 S1|Flores brancas, gengibre e baunilha quente
H3 G2 W2 C1 R1|Hortelã, cítricos e baunilha amadeirada
H3 W2 A2 C1 B1|Ervas, água fresca e fundo amadeirado
C3 H2 W1 M1 B1|Cítricos mediterrâneos, ervas e maciez limpa
F3 R2 A1 M1|Flores delicadas, frutas e frescor aquoso
B3 F2 W2 S1|Flores escuras, especiarias e madeira quente
C3 R2 W2 M1|Limão, maçã e madeira clara
C3 A2 H2 W1|Cítricos, brisa marinha e ervas
B3 F2 R1 G1|Flores, frutas macias e baunilha quente
B3 S2 W2 G1|Madeiras, especiarias e calor de tabaco
G3 C2 F2 B1|Limão açucarado, flores brancas e baunilha
F2 M3 B2 W1 S1|Flores atalcadas, limpeza macia e âmbar
H3 W2 B1 C1 T1|Lavanda, madeira e frescor mineral
H2 M2 W2 C1 F1|Ervas frescas, flores e madeira limpa
F3 B2 M2 C1|Flores brancas, âmbar e fundo macio
G3 B2 M1|Caramelo, baunilha e maciez ambarada
F3 G2 W2 B1|Flores brancas, baunilha e madeira
W3 H2 T1 S1 A1|Madeira, ervas, gengibre e toque mineral
F3 G2 C1 T1|Flores brancas, cítricos e baunilha
F3 B2 W1 G1|Rosa e flores atalcadas com fundo quente
W3 F2 B2 G1|Madeiras, flores macias e calor suave
F3 V1 M1|Flores brancas intensas e frescor de jardim
F3 G2 R2|Flores brancas, pera e doçura delicada
F3 C2 W1|Jasmim, cítricos e madeira macia
H3 W2 C2 F1|Lavanda, limão e fundo amadeirado
F3 B2 R1 T1|Flores, frutas cítricas e calor terroso
R3 F2 M1 B1|Frutas vermelhas, flores e fundo macio
G3 H2 B2|Baunilha em destaque com lavanda
G2 R2 B2 W1|Frutas, amêndoas doces e madeira quente
F3 R1 W1 M1|Flores brancas com toque frutado e madeira
W3 C2 S1 H1|Cedro, cítricos e especiarias secas
W2 R2 S2 G1|Maçã, especiarias e madeira quente
B2 W2 S2 R1|Gengibre, fruta e fundo quente amadeirado
V3 H2 R2 W1 C1|Maçã verde, ervas frescas e madeira
G3 W2 R2 B1|Baunilha, frutas e madeira cremosa
W3 H2 M1 S1 V1|Madeiras, folhas e frescor aromático
C3 H2 V1 M1 F1|Cítricos leves, ervas e flores limpas
M3 H2 C1 F1 W1|Limpeza macia, ervas e cítricos suaves
F3 V2 M1 W1|Flores verdes e maciez limpa
H3 V2 W2 C1 T1|Ervas, folhas verdes e madeira
F3 R2 W1 G1|Flores escuras, frutas e madeira cremosa
A3 F3 M1 W1|Flores brancas, água fresca e madeira suave
C3 A2 W2 S1|Cítricos luminosos, frescor aquoso e madeira
F3 M2 G1 W1|Flores macias com cremosidade e limpeza
W3 C2 A1 R1 S1|Limão, coco e madeiras quentes
W3 T2 B2 C1|Madeira escura, raízes e calor ambarado
M3 F2 B1 W1|Maciez de pele limpa, flores e âmbar
M3 F2 R1 W1|Rosa, fruta macia e fundo de pele limpa
M3 F2 W1|Limpeza macia, flores brancas e madeira
M3 F2 G2 R1 B1|Flores cremosas, ameixa, baunilha e maciez
M3 F2 W2|Talco macio, flores e madeira
F3 R2 V1 M1|Flores delicadas, morango e folhas suaves
R3 F2 V1 M1|Frutas leves, flores e frescor verde
F3 G1 W1 R1|Flores confortáveis e madeira cremosa
G2 F2 R2 M1 W1|Frutas doces, flores e madeira macia
R3 F2 A1 W1|Frutas suculentas, flores e leveza aquosa
F3 M2 R1 W1|Rosa, flores frescas e maciez atalcada
T3 F2 R2 W1|Musgo terroso, flores e ameixa
F3 G2 B1 T1|Rosa luminosa e baunilha ambarada
F3 W2 R2 B1|Rosa intensa, framboesa e madeira
B3 F2 G1 S1|Flores brancas, resinas e calor doce
W3 T3 C2 S1|Madeira seca, pedra e cítricos
V3 R2 F1 W1 A1|Fruta verde, flores aquosas e madeira
V3 W2 R2 F1|Figueira, folhas verdes e flores suaves
F3 S2 W1|Flores brancas, gengibre e madeira
V3 H2 M1 T1|Ervas verdes, frescor e toque mineral
F3 T2 B2 G1 R1|Flores escuras, terra, frutas e calor doce
W3 B2 S1 T1|Madeiras escuras e calor de especiarias
G3 B2 S2 W1 R1|Baunilha, cacau, frutas secas e madeira
C3 F2 H1 M1|Cítricos luminosos, flores brancas e ervas
R3 G2 B2 F1 W1|Cereja, amêndoas e madeira doce
R3 F2 W1 T1|Pera, flores delicadas e fundo amadeirado
A3 H2 W2 T1|Ar salgado, ervas e madeira mineral
C3 H2 V1 W1|Cítricos verdes, manjericão e madeira
F3 R2 M1 W1|Peônia, maçã e flores macias
R3 S2 W2 B1|Frutas escuras, especiarias e madeira quente
R2 W3 C2 T2 M1|Frutas, cítricos e madeira terrosa
V3 H2 W2 F1|Folhas verdes, ervas e madeira fresca
A3 C2 H2 M1 V1|Água fresca, cítricos, chá e maciez limpa
C3 R2 G1 W1|Lima, coco e madeira suave
F3 C1 G1 W1|Flores brancas, cítricos e madeira cremosa
B3 W3 F1 G1 S1|Âmbar luminoso, madeira e flores
F3 C2 M1 W1|Rosas frescas, cítricos e maciez limpa
M3 C2 F2 W1|Roupa limpa, cítricos e flores delicadas
B3 G2 M2 S1 W1|Baunilha ambarada, maciez e especiarias
F3 W3 B2 G1|Rosa, madeira escura e baunilha quente
W3 G2 B2 S1|Madeira queimada, castanhas e baunilha
B3 W2 G2 S1|Tabaco, calor de bebida e baunilha
M3 F2 W1|Lençóis limpos, flores e maciez de pele
A2 R2 F2 M1 G1|Brisa de praia, coco e flores solares
A3 H1 W1 C1|Água do mar, vento fresco e madeira
W3 C2 T2 H1|Cítricos, ervas e madeira terrosa
H3 W2 R1 V1 B1|Lavanda, folhas e madeira macia
H2 W2 S2 G1 M1|Ervas, especiarias e madeira adocicada
M3 G2 F2 C1 B1|Baunilha cremosa, flores e cítricos suaves
A3 M2 C2 W1 H1|Cítricos, água fresca e madeira limpa
W3 F2 H1 C1|Madeira clara, flores brancas e frescor
F3 R2 C1 W1|Flores rosadas, frutas e cítricos
F3 W2 M1 S1|Flores macias, madeira e leve especiaria
F3 C2 W1 G1|Laranja, jasmim e madeira cremosa
V3 H2 A1 W1 C1|Folhas verdes, ervas e frescor aquoso
H3 W2 S2 C1|Ervas clássicas, especiarias e madeira
C3 A2 M2 W1|Cítricos, frescor aquoso e limpeza macia
S3 W2 C2 G1|Especiarias, limão e madeira adocicada
S3 B2 W2 G1|Canela, madeira e calor ambarado
G3 B2 S2 W1|Baunilha quente, gengibre e madeira
'''.strip().splitlines()
assert len(sources) == len(profiles) == 150, (len(sources),len(profiles))
families=json.loads((root/'odores_157.json').read_text(encoding='utf8'))['families']
codes=dict(zip('WBMF G V C A H R S T'.replace(' ',''),families))
# Explicit mapping avoids tying editorial codes to catalog ordering by accident.
codes={'W':'Amadeirado','B':'Ambarado','M':'Almiscarado','F':'Floral','G':'Gourmand','V':'Verde','C':'Cítrico','A':'Aquático','H':'Aromático','R':'Frutado','S':'Especiado','T':'Terroso'}
perfumes=[]
for source,line in zip(sources,profiles):
 spec,summary=line.split('|')
 weights={f:0 for f in families}
 for code,n in re.findall(r'([A-Z])(\d)',spec): weights[codes[code]]=int(n)
 raw=source['queryName']
 concentration=next(c for c in ['Eau de Toilette Intense','Eau de Toilette','Eau de Parfum','Cologne','Parfum'] if c in raw)
 name=raw.replace(concentration,'').strip().replace(' women',' (feminino)')
 if source['index']==50: name='Light Blue (feminino)'
 if source['index']==52: name='The One (feminino)'
 if source['index']==100: name='Chloé'
 if source['index']==102: name='Chloé Lumineuse'
 perfumes.append({'id':f"perfume-{source['index']+1:03d}",'brand':source['brand'],'name':name,'concentration':concentration,'profileSummary':summary,'weights':weights,'sources':[source['source']]})
output={'version':1,'updatedAt':'2026-10-15','method':'Curadoria de 150 perfumes de 30 marcas. Pesos editoriais de 0 a 3 baseados em descrições públicas: não são medidas das marcas, concentração de ingredientes ou estatística de vendas. Sem verificação de estoque local.','perfumes':perfumes}
(root/'assets/perfumes_150.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
lines=['# Fontes do catálogo de perfumes','',output['method'],'','Pesquisa: 15/10/2026. Cada concentração é identificada separadamente. A conversão para 12 famílias e pesos é interpretação editorial, não uma informação quantitativa fornecida pelas marcas. Não há imagens, resenhas ou textos comerciais copiados.','', '| Perfume e versão | Fonte consultada |','| --- | --- |']
for p in perfumes:
 s=p['sources'][0]; lines.append(f"| {p['brand']} · {p['name']} · {p['concentration']} | [{s['title']}]({s['url']}) |")
(root/'FONTES_PERFUMES.md').write_text('\n'.join(lines)+'\n',encoding='utf8')
print('Catálogo offline:',len(perfumes),'perfumes;',len({p['brand'] for p in perfumes}),'marcas')
