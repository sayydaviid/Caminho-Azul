# Caminho Azul — guia de uso da marca

Identidade aprovada pelo responsável em 24/11/2026: proposta **B · Acolhida**, desenho original (rodada 1).

## Ideia

Três peças (escola, família e saúde) formam um nicho em volta do ponto central, que é o estudante. O canto aberto é o caminho adiante. A marca não usa quebra-cabeça nem símbolos genéricos de autismo.

## Versões (`marca/`)

| Uso | Arquivo |
|---|---|
| Símbolo, cor (padrão) | `caminho-azul-simbolo-cor.svg` |
| Símbolo, uma cor | `-simbolo-preto.svg`, `-simbolo-branco.svg`, `-simbolo-azul.svg` |
| Horizontal (símbolo + nome) | `caminho-azul-horizontal-{cor,preto,branco}.svg` |
| Vertical (empilhada) | `caminho-azul-vertical-{cor,preto,branco}.svg` |
| Ícone de app | `caminho-azul-app-icon.svg` (símbolo branco sobre azul, cantos de 22 %) |
| Ícone Android adaptável | `caminho-azul-adaptive-foreground.svg` (primeiro plano; fundo `#2563EB`) |
| Favicon / PWA maskable | `caminho-azul-favicon.svg`, `caminho-azul-maskable.svg` |
| PNG de apoio | `marca/png/` (1024 px e lockups com 1200 px de largura) |

## Cores

| Nome | HEX | RGB | Uso |
|---|---|---|---|
| Azul Caminho | `#2563EB` | 37, 99, 235 | peças do símbolo, "Azul" no nome, fundo do ícone |
| Azul-marinho | `#1E3A5F` | 30, 58, 95 | ponto central, "Caminho" no nome |
| Branco | `#FFFFFF` | 255, 255, 255 | versão invertida |

São as cores do app (`AppColors.primary` e `AppColors.sidebar`). Contraste sobre branco: azul 5,2:1 e marinho 11,5:1. Para impressão em CMYK e Pantone, a conversão deve ser feita e conferida pela gráfica a partir dos valores HEX; este guia não inventa códigos que não foram medidos.

## Tipografia

- O nome usa **Inter SemiBold** (SIL Open Font License, permite uso em logotipo), convertido em contornos nos SVG.
- O app e os PDFs continuam com Roboto.

## Área de proteção e tamanho mínimo

- **Área de proteção:** em volta da marca, deixe livre pelo menos 1/4 da altura do símbolo (a largura de meia peça).
- **Tamanho mínimo do símbolo:** 16 px na tela e 6 mm impresso.
- **Tamanho mínimo da versão horizontal:** 24 px de altura na tela e 10 mm impressa.

## Fundos

- **Cor:** sobre branco ou `#F8FAFC`.
- **Branco:** sobre azul-marinho, sobre o azul Caminho e sobre fotos escuras.
- **Preto:** para documentos sem cor.

## Não fazer

- Não girar, espelhar ou inclinar o símbolo.
- Não mudar as cores das peças nem pintar cada peça de uma cor.
- Não fechar o canto aberto nem mover o ponto.
- Não aplicar sombra, contorno, degradê ou efeitos.
- Não usar a versão colorida sobre o azul Caminho (o símbolo some); use a branca.
- Não recompor o nome com outra fonte nem alterar o espaçamento.

## Onde está aplicado

| Local | Implementação |
|---|---|
| Login e menu lateral | `lib/widgets/brand_mark.dart` (`BrandMark`, desenhado com `CustomPaint`, sem pacote de SVG) |
| Timbre dos PDFs | `brandMarkSvg()` em `pw.SvgImage` (`lib/reports/report_pdf.dart`) |
| Ícone Android | `mipmap-*/ic_launcher.png` (legado) e `mipmap-anydpi-v26/ic_launcher.xml` (adaptável, com monocromático) |
| Splash Android | `drawable*/launch_background.xml` + `drawable-*/launch_logo.png`; no Android 12+ o sistema usa o ícone adaptável |
| Web | `web/favicon.png`, `web/icons/Icon-*.png` e `Icon-maskable-*.png` |
| iOS | sem pasta `ios/` no repositório; gerar os ícones quando a plataforma for criada (P2-15) |
