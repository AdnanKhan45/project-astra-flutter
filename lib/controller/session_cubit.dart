
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_voice_engine/flutter_voice_engine.dart';
import 'package:project_astra_flutter/const/app_constants.dart';
import 'package:project_astra_flutter/controller/session_state.dart';
import 'package:project_astra_flutter/util/utils.dart';
import 'package:web_socket_channel/io.dart';

class SessionCubit extends Cubit<SessionState> {
  SessionCubit() : super(SessionState());

  // Initialize the voice engine and camera controller
  FlutterVoiceEngine? _voiceEngine;
  IOWebSocketChannel? _webSocket;
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];

  // Store the latest CameraImage received from the stream
  // This is read by the timer to send
  CameraImage? _latestCameraImage;

  StreamSubscription<dynamic>? _voiceEngineSubscription;
  Timer? _imageSendTimer; // Timer for sending images every or 2 seconds

  bool _isInitialized = false; // Overall session initialized
  bool _isWebSocketOpen = false;
  bool _isCameraInitialized = false; // Camera specifically initialized

  // Getter to expose CameraController to the UI for CameraPreview
  CameraController? get cameraController => _cameraController;

  @override
  Future<void> close() async {
    print('Closing Session Cubit');
    _imageSendTimer?.cancel();
    _imageSendTimer = null;
    _latestCameraImage = null; // Clear latest image
    await _voiceEngine?.shutdownAll();
    await _cameraController?.stopImageStream(); // Stop image stream
    await _cameraController?.dispose(); // Dispose camera controller
    _cameraController = null;
    _isCameraInitialized = false;
    _webSocket?.sink.close();
    _isWebSocketOpen = false;
    super.close();
  }

  Future<void> startSession() async {
    print('Starting session');

    await AstraUtils.requestMicrophonePermission();
    await AstraUtils.requestCameraPermission();

    if (_isInitialized) {
      print('Already initialized, attempting to reconnect/resume.');
      // If already initialized but maybe WebSocket disconnected, try to reconnect
      if (!_isWebSocketOpen) {
        connectWebSocket();
      }
      // Audio and camera will start after successful WebSocket connection
      emit(state.copyWith(isSessionStarted: true));
      return;
    }

    try {

      await _initVoiceEngine();
      _isInitialized = true;
      connectWebSocket(); // Camera and audio will start after websocket successfully_connected
      emit(
        state.copyWith(
          isSessionStarted: true,
          isError: false,
          error: null,
          isCameraActive: false, // Will be set true once camera starts
          isStreamingImages: false, // Will be true once streaming
        ),
      );
    } catch (e, stackTrace) {
      print('Initialization failed: $e\n$stackTrace');
      emit(
        state.copyWith(
          error: 'Initialization failed: $e',
          isError: true,
          isSessionStarted: false,
        ),
      );
    }
  }

  Future<void> stopSession() async {
    print('Stopping session');
    _imageSendTimer?.cancel();
    _imageSendTimer = null;
    _latestCameraImage = null;

    await _voiceEngine?.stopPlayback();
    if(Platform.isAndroid) {
      await _voiceEngine?.shutdownAll();
    } else {
      await _voiceEngine?.shutdownBot();
    }

    if (_cameraController != null) {
      emit(state.copyWith(
        isCameraActive: false,
        showCameraPreview: false,
        isStreamingImages: false,
      ));

      await _cameraController?.stopImageStream();
      await _cameraController?.dispose();
      _cameraController = null;
      _isCameraInitialized = false;
    }

    _webSocket?.sink.close();
    _isWebSocketOpen = false;
    _isInitialized = false;
    emit(state.copyWith(
      isSessionStarted: false,
      isRecording: false,
      isCameraActive: false,
      showCameraPreview: false,
      isStreamingImages: false,
      connecting: false,
      isError: false,
      error: null,
    ));
  }

  Future<void> _initVoiceEngine() async {
    print('Initializing VoiceEngine');
    try {
      if (_voiceEngine != null && _voiceEngine!.isInitialized) {
        print('VoiceEngine already initialized, reusing.');
        return;
      }

      _voiceEngine = FlutterVoiceEngine();
      _voiceEngine!.audioConfig = AudioConfig(
        sampleRate: 16000,
        channels: 1,
        bitDepth: 16,
        bufferSize: 4096,
        enableAEC: true,
      );
      _voiceEngine!.sessionConfig = AudioSessionConfig(
        category: AudioCategory.playAndRecord,
        mode: AudioMode.spokenAudio,
        options: {AudioOption.defaultToSpeaker, AudioOption.allowBluetoothA2DP, AudioOption.mixWithOthers},
      );
      await _voiceEngine!.initialize();
      print('VoiceEngine initialized');
    } catch (e, stackTrace) {
      print('VoiceEngine initialization failed: $e\n$stackTrace');
      rethrow;
    }
  }

  void connectWebSocket() {
    print('Connecting to WebSocket');
    try {
      _webSocket = IOWebSocketChannel.connect(Uri.parse(AstraConst.wssUrl));
      _isWebSocketOpen = true;

      _webSocket!.stream.listen(
            (message) => _handleWebSocketMessage(message),
        onDone: () {
          print('WebSocket disconnected.');
          _isWebSocketOpen = false;
          emit(state.copyWith(
              isSessionStarted: false,
              isRecording: false,
              isError: true,
              error: 'WebSocket disconnected. Ending session.'));
          // Stop camera and audio when websocket disconnects
          _stopAllStreams();
        },
        onError: (error, stackTrace) {
          print('WebSocket error: $error\n$stackTrace');
          _isWebSocketOpen = false;
          emit(state.copyWith(
              isError: true,
              error: 'WebSocket error: $error',
              isSessionStarted: false));
          // Stop camera and audio on error
          _stopAllStreams();
        },
      );
      print('WebSocket connection attempt successful.');
    } catch (e, stackTrace) {
      print('WebSocket connection failed: $e\n$stackTrace');
      emit(
        state.copyWith(error: 'WebSocket connection failed: $e', isError: true),
      );
    }
  }

  Future<void> _handleWebSocketMessage(dynamic message) async {

    try {
      if(message is String) {
        final data = jsonDecode(message);
        final type = data['type'] as String;
        switch (type) {
          case 'instantiating_connection':
            print('Gemini session is being set up...');
            emit(state.copyWith(connecting: true));
            break;
          case 'successfully_connected':
            print('Gemini session established! Starting audio...');
            await startRecording();
            print('Audio ready, initializing camera...');
            await _initCamera();
            emit(state.copyWith(isSessionStarted: true, connecting: false));
            break;
          case 'error':
            final errorMsg = data['message'] as String? ?? 'Unknown error';
            print('Backend error: $errorMsg');
            emit(state.copyWith(error: errorMsg, isError: true));
            _stopAllStreams(); // Stop all operations on backend error
            break;
          case 'turn_complete':
            print('TURN COMPLETE received');
            await _voiceEngine!.stopPlayback();
            emit(state.copyWith(
              isBotSpeaking: false,
            ));
            break;
          case 'interrupted':
            print('INTERRUPTED received');
            await _voiceEngine!.stopPlayback();
            emit(state.copyWith(
              isBotSpeaking: false,
            ));
            break;
          default:
            print('Unhandled message type: $type');
        }
      } else {
        final Uint8List audioData = message as Uint8List;
        final amplitude = computeRMSAmplitude(audioData);
        emit(state.copyWith(isBotSpeaking: true, visualizerAmplitude: amplitude));
        try {
          print("Playing audio chunk of size: ${audioData.length} bytes");
          await _voiceEngine!.playAudioChunk(audioData);
        } catch (e, stackTrace) {
          print('Playback error: $e\n$stackTrace');
          emit(state.copyWith(error: 'Playback error: $e', isError: true));
        }
      }

    } catch (e, stackTrace) {
      print('WebSocket message error: $e\n$stackTrace');
      emit(state.copyWith(error: 'WebSocket message error: $e', isError: true));
    }
  }

  Future<void> _stopAllStreams() async {
    _imageSendTimer?.cancel();
    _imageSendTimer = null;
    _latestCameraImage = null;
    await stopRecording(); // Sends audio_stream_end
    await _cameraController?.stopImageStream();
    await _cameraController?.dispose();
    _cameraController = null;
    _isCameraInitialized = false;
    emit(state.copyWith(
      isRecording: false,
      isCameraActive: false,
      showCameraPreview: false,
      isStreamingImages: false,
      connecting: false,
      isBotSpeaking: false,
    ));
  }

  // --- CAMERA METHODS FOR CONTINUOUS STREAMING ---

  Future<void> _initCamera() async {
    print('Initializing Camera');
    emit(state.copyWith(isInitializingCamera: true, error: null, isError: false));
    try {
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        print('Camera already initialized, reusing.');
        return;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw Exception("No cameras available on this device.");
      }

      CameraDescription? backCamera;
      for (var camera in _cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          backCamera = camera;
          break;
        }
      }
      final camera = backCamera ?? _cameras.first;

      // --- CRUCIAL CHANGE: Set imageFormatGroup based on platform ---
      ImageFormatGroup desiredFormat;
      if (Platform.isIOS) {
        desiredFormat = ImageFormatGroup.bgra8888; // More stable on iOS
        print('Configuring camera for iOS with ImageFormatGroup.bgra8888');
      } else if (Platform.isAndroid) {
        desiredFormat = ImageFormatGroup.yuv420; // Common on Android
        print('Configuring camera for Android with ImageFormatGroup.yuv420');
      } else {
        // Fallback for other platforms (e.g., desktop) if camera plugin supports it
        desiredFormat = ImageFormatGroup.yuv420; // Defaulting to YUV420
        print('Configuring camera for unknown platform with ImageFormatGroup.yuv420');
      }


      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: desiredFormat, // Use the dynamically chosen format
      );

      await _cameraController!.initialize();
      _isCameraInitialized = true;
      print('Camera initialized. Starting image stream...');

      _cameraController!.startImageStream((CameraImage image) {
        _latestCameraImage = image;
      });

      emit(state.copyWith(
        isInitializingCamera: false,
        isCameraActive: true,
        showCameraPreview: true,
        isStreamingImages: true,
      ));

      _startImageSendTimer();
    } catch (e, stackTrace) {
      print('Camera initialization failed: $e\n$stackTrace');
      emit(state.copyWith(
        isInitializingCamera: false,
        isCameraActive: false,
        showCameraPreview: false,
        isStreamingImages: false,
        error: 'Camera initialization failed: $e',
        isError: true,
      ));
      await _cameraController?.dispose();
      _cameraController = null;
      _isCameraInitialized = false;
    }
  }

  void _startImageSendTimer() {
    _imageSendTimer?.cancel(); // Cancel any previous timer
    _imageSendTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      if (_latestCameraImage != null && _webSocket != null && _isWebSocketOpen) {
        try {
          // Convert CameraImage to JPEG bytes in a background isolate for performance
          final Uint8List? jpegBytes = await compute(AstraUtils.convertCameraImageToJpeg, _latestCameraImage!);

          print("Converted CameraImage to JPEG bytes: ${jpegBytes?.length} bytes");
          if (jpegBytes != null) {
            final String base64Image = base64Encode(jpegBytes);

            final Map<String, dynamic> imageMessage = {
              "type": "image_input",
              "image_data": base64Image,
              "mime_type": "image/jpeg", // We're converting to JPEG
            };

            print("sending image to backend via timer");

            _webSocket!.sink.add(jsonEncode(imageMessage));
            // print('[FRONTEND] Sent image to backend via timer.'); // Too verbose
          }
        } catch (e, stackTrace) {
          print("Error processing/sending timed picture: $e\n$stackTrace");
          // Consider a less aggressive error display for continuous stream issues
          // emit(state.copyWith(error: 'Timed image capture error: $e', isError: true));
        }
      } else if (_cameraController == null || !_cameraController!.value.isInitialized) {
        print("Camera not active for timed image send. Stopping timer.");
        timer.cancel();
        _imageSendTimer = null;
        emit(state.copyWith(isStreamingImages: false)); // Update state
      }
    });
  }

  Future<void> switchCamera() async {
    if (_cameraController != null && _cameras.isNotEmpty) {
      try {
        final CameraDescription currentCamera = _cameraController!.description;
        int nextCameraIndex = _cameras.indexOf(currentCamera) == 0 ? 1 : 0;

        // Dispose of the current controller
        await _cameraController?.dispose();
        _cameraController = null; // Clear reference immediately

        ImageFormatGroup desiredFormat;
        if (Platform.isIOS) {
          desiredFormat = ImageFormatGroup.bgra8888; // More stable on iOS
          print('Configuring camera for iOS with ImageFormatGroup.bgra8888');
        } else if (Platform.isAndroid) {
          desiredFormat = ImageFormatGroup.yuv420; // Common on Android
          print('Configuring camera for Android with ImageFormatGroup.yuv420');
        } else {
          // Fallback for other platforms (e.g., desktop) if camera plugin supports it
          desiredFormat = ImageFormatGroup.yuv420; // Defaulting to YUV420
          print('Configuring camera for unknown platform with ImageFormatGroup.yuv420');
        }

        // Initialize the new controller
        _cameraController = CameraController(
          _cameras[nextCameraIndex],
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: desiredFormat
        );

        await _cameraController!.initialize();

        _isCameraInitialized = true;
        print('Camera initialized. Starting image stream...');

        _cameraController!.startImageStream((CameraImage image) {
          _latestCameraImage = image;
        });

        emit(state.copyWith(
          isInitializingCamera: false,
          isCameraActive: true,
          showCameraPreview: true,
          isStreamingImages: true,
        ));

      } catch (e) {
        print('Error switching camera: $e');
        emit(state.copyWith(error: 'Error switching camera: $e', isError: true));
      } finally {
        _isCameraInitialized = false; // Reset flag
      }
    }
  }

  // --- AUDIO RECORDING METHODS ---

  Future<void> startRecording() async {
    print('Starting recording');
    try {
      if (!_voiceEngine!.isInitialized) {
        await _initVoiceEngine();
      }
      _voiceEngineSubscription?.cancel();
      _voiceEngineSubscription = _voiceEngine!.audioChunkStream.listen(
            (audioData) {
          if (_webSocket != null && _isWebSocketOpen && state.isRecording) {
            _webSocket!.sink.add(audioData); // Send audio as binary
          }

          final amplitude = computeRMSAmplitude(audioData);
          emit(state.copyWith(visualizerAmplitude: amplitude));
        },
        onError: (error, stackTrace) {
          print('Recording error: $error\n$stackTrace');
          emit(state.copyWith(error: 'Recording error: $error', isError: true));
        },
      );
      await _voiceEngine!.startRecording();
      emit(state.copyWith(isRecording: true)); // User is speaking, so no need to prompt
    } catch (e, stackTrace) {
      print('Failed to start recording: $e\n$stackTrace');
      emit(
        state.copyWith(error: 'Failed to start recording: $e', isError: true),
      );
    }
  }

  Future<void> stopRecording() async {
    print('Stopping recording');
    try {
      _voiceEngineSubscription?.cancel();
      _voiceEngineSubscription = null;
      if (_voiceEngine!.isRecording) {
        await _voiceEngine!.stopRecording();
      }
      // Send audioStreamEnd when stopping recording
      if (_webSocket != null && _isWebSocketOpen) {
        _webSocket!.sink.add(jsonEncode({"type": "audio_stream_end"}));
      }
      emit(state.copyWith(isRecording: false));
    } catch (e, stackTrace) {
      print('Error stopping recording: $e\n$stackTrace');
      emit(
        state.copyWith(error: 'Error stopping recording: $e', isError: true),
      );
    }
  }

  double computeRMSAmplitude(Uint8List pcm, {int bytesPerSample = 2}) {
    if (pcm.isEmpty) return 0.0;
    int sampleCount = pcm.length ~/ bytesPerSample;
    if (sampleCount == 0) return 0.0;
    double sumSquares = 0;
    for (int i = 0; i < pcm.length; i += bytesPerSample) {
      int sample = pcm.buffer.asByteData().getInt16(i, Endian.little);
      sumSquares += sample * sample;
    }
    double rms = sqrt(sumSquares / sampleCount) / 32768.0; // 16-bit PCM
    return rms.clamp(0.0, 1.0);
  }

}