# Serviço — `img_preload.dart`

O img_preloader é um serviço de pré-renderização (precache) de imagens de assets no Flutter, reduzindo flicker/lag quando as imagens são exibidas pela primeira vez. O arquivo vem com cache interno, callbacks de progresso, com versão sequencial e paralela, e um ImagePreloaderWidget que exibe um loading enquanto as imagens são carregadas.

Para usar o arquivo, traga-o para a pasta `/lib` do seu projeto Flutter, e importe-o nos arquivos `.dart` desejados.

* Certifique-se de **declarar as imagens no seu arquivo `pubspec.yaml`** (flutter -> assets) — pois o serviço usa `AssetImage`.

## Como funciona (visão rápida)

* `ImagePreloader` é um **singleton** que mantém um `Set<String>` (`_preloadedImages`) com caminhos já carregados para evitar recarregamentos.
* Oferece duas rotas de carregamento:

  * `preloadImages(...)` — carrega **sequencialmente** (mais seguro em memória).
  * `preloadImagesParallel(...)` — carrega **em paralelo** (mais rápido, maior consumo de memória).
* Callbacks disponíveis: `onProgress`, `onComplete`, `onError`.
* Métodos utilitários: `isImagePreloaded(path)`, `areAllImagesPreloaded(list)`, `clearCache()`, `preloadedCount`, `isPreloading`.
* `ImagePreloaderWidget` é um `StatefulWidget` pronto para envolver seu conteúdo (ex.: tela inicial); enquanto as imagens são carregadas ele mostra `loadingWidget` (ou um `CircularProgressIndicator` padrão).

---

## Funcionamento de funções e variáveis

* `Future<void> preloadImages(List<String> imagePaths, BuildContext context, {onProgress, onComplete, onError})`
  Carregamento **sequencial** de `AssetImage(imagePath)`.

* `Future<void> preloadImagesParallel(List<String> imagePaths, BuildContext context, {onProgress, onComplete, onError})`
  Carregamento **paralelo** (usa `Future.wait` internamente).

* `bool isImagePreloaded(String imagePath)` — verifica se já foi carregada.

* `bool areAllImagesPreloaded(List<String> imagePaths)` — verifica lista inteira.

* `void clearCache()` — limpa o cache interno.

* `int get preloadedCount` / `bool get isPreloading` — estado útil para debug/UI.

* `ImagePreloaderWidget({ required List<String> imagePaths, required Widget child, Widget? loadingWidget, bool preloadInParallel = false, ... })`
  Envolva sua árvore de widgets; ele faz o preload automaticamente ao entrar na árvore e mostra `loadingWidget` até terminar.

---

## Exemplos de uso


### Usando o serviço diretamente

```dart
import 'package:cafezin/services/img_preload.dart';


class _MeuArquivoState extends State<MeuArquivo> {

    final ImagePreloader _imagePreloader = ImagePreloader();

    // Em um método async com BuildContext disponível:
    await preloader.preloadImages(
      ['assets/img1.png', 'assets/img2.png'],
      context,
      onProgress: (current, total) => print('$current / $total'), // opcional
      onComplete: () => print('Todas carregadas'), // opcional
      onError: (path, err) => print('Erro $path: $err'), // opcional
    );

    // resto do código...
}
```

### Carregamento paralelo (mais rápido, maior uso de memória)

```dart
import 'package:cafezin/services/img_preload.dart';


class _MeuArquivoState extends State<MeuArquivo> {

    final ImagePreloader _imagePreloader = ImagePreloader();

    await preloader.preloadImagesParallel(
      ['assets/a.png', 'assets/b.png', 'assets/c.png'],
      context,
      onProgress: (completed, total) => print('$completed / $total'), // opcional
    );

    // resto do código...
}
```

### Usando o widget pronto, no seco (ideal para splash / tela inicial)

```dart
import 'package:cafezin/services/img_preload.dart';


class _MeuArquivoState extends State<MeuArquivo> {

    @override
    void didChangeDependencies() {
      super.didChangeDependencies();
      ImagePreloaderWidget(
        imagePaths: [
          'assets/splash_bg.png',
          'assets/logo.png',
        ],
        preloadInParallel: false,
        loadingWidget: Center(child: CircularProgressIndicator()),
        child: HomeScreen(), // exibido após o preload
      )
    }

    // resto do código...
}
```

---

## Regras e Dicas para pré-renderização **efetiva**

* Use **sequencial** (`preloadImages`) em dispositivos com pouca memória; use **paralelo** (`preloadImagesParallel`) para velocidade em dispositivos modernos.
* **Não** pré-carregue todas as de imagens de uma vez no projeto — prefira renderizar aquilo que irá aparecer agora para o usuário (landing page → home → galeria sob demanda).
* Mostre progresso (callback `onProgress`) para UX melhor em telas que travam.
* TODO: Para **imagens remotas (NetworkImage)**: o arquivo usa `AssetImage` por padrão — adapte para `precacheImage(NetworkImage(url), context)` ou altere o preloader para suportar `NetworkImage`.
* Limpe o cache (`clearCache()`) se o conjunto de imagens mudar significativamente ou para liberar memória.

---

## Notas importantes

* O serviço evita recarregar imagens já pré-carregadas (olhe em `_preloadedImages`).
* `preloadImagesParallel` é mais rápido, **mas** pode aumentar consumo de memória.
* Integre o preload em uma **SplashScreen** ou no `didChangeDependencies` / `initState` da primeira tela para melhores resultados.
