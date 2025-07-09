class SessionState {
  final bool isSessionStarted;
  final bool isRecording;

  final bool isError;
  final String? error;

  final bool isInitializingCamera;
  final bool isCameraActive;
  final bool showCameraPreview;
  final bool isStreamingImages;

  final bool connecting;
  final bool isBotSpeaking;

  SessionState({
    this.isSessionStarted = false,
    this.isRecording = false,
    this.isError = false,
    this.error,
    this.isInitializingCamera = false,
    this.isCameraActive = false,
    this.showCameraPreview = false,
    this.isStreamingImages = false,
    this.connecting = false,
    this.isBotSpeaking = false,
  });

  SessionState copyWith({
    bool? isSessionStarted,
    bool? isRecording,
    bool? isError,
    String? error,
    bool? isInitializingCamera,
    bool? isCameraActive,
    bool? showCameraPreview,
    bool? isStreamingImages,
    bool? isBotSpeaking,
    bool? connecting,
  }) {
    return SessionState(
      isSessionStarted: isSessionStarted ?? this.isSessionStarted,
      isRecording: isRecording ?? this.isRecording,
      isError: isError ?? this.isError,
      error: error ?? this.error,
      isInitializingCamera: isInitializingCamera ?? this.isInitializingCamera,
      isCameraActive: isCameraActive ?? this.isCameraActive,
      showCameraPreview: showCameraPreview ?? this.showCameraPreview,
      isStreamingImages: isStreamingImages ?? this.isStreamingImages,
      connecting: connecting ?? this.connecting,
      isBotSpeaking: isBotSpeaking ?? this.isBotSpeaking,
    );
  }
}
