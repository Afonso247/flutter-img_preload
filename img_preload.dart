import 'package:flutter/material.dart';

/// Serviço para precarregar imagens de asset
class ImagePreloader {
  static final ImagePreloader _instance = ImagePreloader._internal();
  factory ImagePreloader() => _instance;
  ImagePreloader._internal();

  // Cache para controlar quais imagens já foram precarregadas
  final Set<String> _preloadedImages = <String>{};
  bool _isPreloading = false;

  /// Precarrega uma lista de imagens
  /// 
  /// [imagePaths] - Lista com caminhos das imagens
  /// [context] - BuildContext necessário para precacheImage
  /// [onProgress] - Callback opcional para acompanhar progresso
  /// [onComplete] - Callback opcional chamado quando terminar
  /// [onError] - Callback opcional para tratar erros
  Future<void> preloadImages(
    List<String> imagePaths,
    BuildContext context, {
    Function(int current, int total)? onProgress,
    VoidCallback? onComplete,
    Function(String imagePath, dynamic error)? onError,
  }) async {
    if (_isPreloading) {
      debugPrint('ImagePreloader: Já está precarregando imagens');
      return;
    }

    _isPreloading = true;
    final stopwatch = Stopwatch()..start();
    
    debugPrint('ImagePreloader: Iniciando precarregamento de ${imagePaths.length} imagens');

    try {
      for (int i = 0; i < imagePaths.length; i++) {
        final imagePath = imagePaths[i];
        
        // Pula se já foi precarregada
        if (_preloadedImages.contains(imagePath)) {
          onProgress?.call(i + 1, imagePaths.length);
          continue;
        }

        try {
          await precacheImage(AssetImage(imagePath), context);
          _preloadedImages.add(imagePath);
          onProgress?.call(i + 1, imagePaths.length);
          
          debugPrint('ImagePreloader: ✅ $imagePath precarregada');
        } catch (error) {
          debugPrint('ImagePreloader: ❌ Erro ao precarregar $imagePath: $error');
          onError?.call(imagePath, error);
        }
      }
      
      stopwatch.stop();
      debugPrint('ImagePreloader: ✅ Precarregamento concluído em ${stopwatch.elapsedMilliseconds}ms');
      onComplete?.call();
      
    } finally {
      _isPreloading = false;
    }
  }

  /// Precarrega imagens em paralelo (mais rápido, mas usa mais memória)
  Future<void> preloadImagesParallel(
    List<String> imagePaths,
    BuildContext context, {
    Function(int completed, int total)? onProgress,
    VoidCallback? onComplete,
    Function(List<String> failedImages)? onError,
  }) async {
    if (_isPreloading) {
      debugPrint('ImagePreloader: Já está precarregando imagens');
      return;
    }

    _isPreloading = true;
    final stopwatch = Stopwatch()..start();
    int completedCount = 0;
    final failedImages = <String>[];
    
    debugPrint('ImagePreloader: Iniciando precarregamento paralelo de ${imagePaths.length} imagens');

    try {
      final futures = imagePaths.map((imagePath) async {
        if (_preloadedImages.contains(imagePath)) {
          completedCount++;
          onProgress?.call(completedCount, imagePaths.length);
          return;
        }

        try {
          await precacheImage(AssetImage(imagePath), context);
          _preloadedImages.add(imagePath);
          debugPrint('ImagePreloader: ✅ $imagePath precarregada');
        } catch (error) {
          failedImages.add(imagePath);
          debugPrint('ImagePreloader: ❌ Erro ao precarregar $imagePath: $error');
        } finally {
          completedCount++;
          onProgress?.call(completedCount, imagePaths.length);
        }
      }).toList();

      await Future.wait(futures);
      
      stopwatch.stop();
      debugPrint('ImagePreloader: ✅ Precarregamento paralelo concluído em ${stopwatch.elapsedMilliseconds}ms');
      
      if (failedImages.isNotEmpty) {
        onError?.call(failedImages);
      }
      
      onComplete?.call();
      
    } finally {
      _isPreloading = false;
    }
  }

  /// Verifica se uma imagem já foi precarregada
  bool isImagePreloaded(String imagePath) {
    return _preloadedImages.contains(imagePath);
  }

  /// Verifica se todas as imagens de uma lista foram precarregadas
  bool areAllImagesPreloaded(List<String> imagePaths) {
    return imagePaths.every((path) => _preloadedImages.contains(path));
  }

  /// Limpa o cache de imagens precarregadas
  void clearCache() {
    _preloadedImages.clear();
    debugPrint('ImagePreloader: Cache limpo');
  }

  /// Retorna o número de imagens precarregadas
  int get preloadedCount => _preloadedImages.length;

  /// Retorna se está precarregando no momento
  bool get isPreloading => _isPreloading;

  /// Lista das imagens precarregadas
  List<String> get preloadedImages => _preloadedImages.toList();
}

/// Widget helper para precarregar imagens facilmente
class ImagePreloaderWidget extends StatefulWidget {
  final List<String> imagePaths;
  final Widget child;
  final Widget? loadingWidget;
  final bool preloadInParallel;
  final Function(int current, int total)? onProgress;
  final VoidCallback? onComplete;
  final Function(dynamic error)? onError;

  const ImagePreloaderWidget({
    super.key,
    required this.imagePaths,
    required this.child,
    this.loadingWidget,
    this.preloadInParallel = false,
    this.onProgress,
    this.onComplete,
    this.onError,
  });

  @override
  State<ImagePreloaderWidget> createState() => _ImagePreloaderWidgetState();
}

class _ImagePreloaderWidgetState extends State<ImagePreloaderWidget> {
  final ImagePreloader _preloader = ImagePreloader();
  bool _isLoading = true;
  int _currentProgress = 0;
  int _totalImages = 0;

  @override
  void initState() {
    super.initState();
    _totalImages = widget.imagePaths.length;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startPreloading();
  }

  Future<void> _startPreloading() async {
    if (_preloader.areAllImagesPreloaded(widget.imagePaths)) {
      setState(() {
        _isLoading = false;
        _currentProgress = _totalImages;
      });
      widget.onComplete?.call();
      return;
    }

    try {
      if (widget.preloadInParallel) {
        await _preloader.preloadImagesParallel(
          widget.imagePaths,
          context,
          onProgress: (current, total) {
            setState(() {
              _currentProgress = current;
            });
            widget.onProgress?.call(current, total);
          },
          onComplete: () {
            setState(() {
              _isLoading = false;
            });
            widget.onComplete?.call();
          },
          onError: (failedImages) {
            widget.onError?.call('Falha ao carregar: ${failedImages.join(', ')}');
          },
        );
      } else {
        await _preloader.preloadImages(
          widget.imagePaths,
          context,
          onProgress: (current, total) {
            setState(() {
              _currentProgress = current;
            });
            widget.onProgress?.call(current, total);
          },
          onComplete: () {
            setState(() {
              _isLoading = false;
            });
            widget.onComplete?.call();
          },
          onError: (imagePath, error) {
            widget.onError?.call('Erro ao carregar $imagePath: $error');
          },
        );
      }
    } catch (error) {
      widget.onError?.call(error);
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingWidget ??
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Carregando imagens... $_currentProgress/$_totalImages',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
    }

    return widget.child;
  }
}