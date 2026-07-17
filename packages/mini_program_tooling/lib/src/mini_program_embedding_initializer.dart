import 'host_integration/embedding/initializer.dart';
import 'host_integration/embedding/models.dart';

export 'host_integration/embedding/models.dart'
    show
        MiniProgramEmbeddingInitException,
        MiniProgramEmbeddingInitRequest,
        MiniProgramEmbeddingInitResult;

class MiniProgramEmbeddingInitializer {
  const MiniProgramEmbeddingInitializer();

  Future<MiniProgramEmbeddingInitResult> initialize(
    MiniProgramEmbeddingInitRequest request,
  ) {
    return initializeMiniProgramEmbedding(request);
  }
}
