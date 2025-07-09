import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_astra_flutter/const/app_colors.dart';
import 'package:project_astra_flutter/controller/session_cubit.dart';
import 'package:project_astra_flutter/controller/session_state.dart';
import 'package:project_astra_flutter/widgets/blur_clipper.dart';
import 'package:project_astra_flutter/widgets/loading_widget.dart';
import 'package:project_astra_flutter/widgets/voice_visualizer.dart';

class SessionPage extends StatefulWidget {
  const SessionPage({super.key});

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> with WidgetsBindingObserver {

  @override
  void initState() {
    context.read<SessionCubit>().startSession();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final double horizontalPadding = MediaQuery.of(context).size.width * 0.001;
    final double verticalPadding =
        MediaQuery.of(context).size.height * 0.19; // 19% of screen height

    // Define the radius for the rounded corners of the clear area
    final double borderRadius = 30.0;

    return Scaffold(
      body: BlocConsumer<SessionCubit, SessionState>(
        listener: (context, state) {
          if (state.isError && state.error != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.error!)));
          }
        },
        builder: (context, state) {
          final cubit = context.read<SessionCubit>();
          final cameraController = cubit.cameraController;

          if (state.isInitializingCamera) {
            return LoadingWidget();
          }

          return Stack(
            children: [
              if (state.showCameraPreview &&
                  cameraController != null &&
                  cameraController.value.isInitialized)
                buildCameraPreview(context, cameraController)
              else
                Center(
                  child: CircularProgressIndicator(
                    color: AstraColors.primary,
                  ),
                ),

              // 2. The full-screen blur effect with a "hole" for the clear preview
              Positioned.fill(
                child: ClipPath(
                  clipper: CameraBlurClipper(
                    horizontalPadding: horizontalPadding,
                    verticalPadding: verticalPadding,
                    borderRadius: borderRadius,
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                    child: Container(
                      // Use a standard color with opacity, assuming AstraColors.withValues is a custom extension
                      color: Colors.black.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ),

              _buildSwitchCameraButton(onTap: cubit.switchCamera),

              // TOP Layer
              _buildTopLayer(verticalPadding),

              // BOTTOM Layer
              _buildBottomLayer(verticalPadding),
            ],
          );
        },
      ),
    );
  }

  Widget buildCameraPreview(
    BuildContext context,
    CameraController? controller,
  ) {
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;
    final cameraRatio = controller!.value.aspectRatio;

    return OverflowBox(
      maxWidth: deviceRatio > cameraRatio
          ? size.width
          : size.height * cameraRatio,
      maxHeight: deviceRatio > cameraRatio
          ? size.width / cameraRatio
          : size.height,
      child: CameraPreview(controller),
    );
  }

  Widget _buildTopLayer(double verticalPadding) {
    return Positioned(
      top: -20,
      left: 0,
      right: 0,
      height: verticalPadding, // Height of the top blurred area
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            alignment: Alignment.center,
            child: const Text(
              "Project Astra",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.white70, width: 0.8),
            ),
            child: Text(
              "EXP Flutter",
              style: TextStyle(fontSize: 8, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomLayer(double verticalPadding) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      height: verticalPadding, // Height of the bottom blurred area
      child: Padding(
        padding: const EdgeInsets.only(left: 12, right: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox.shrink(),
            Padding(
              padding: const EdgeInsets.only(left: 40.0),
              child: Row(
                children: [
                  _bottomButton(
                    radius: 10,
                    width: 55,
                    height: 55,
                    bgColor: AstraColors.greyBorder,
                    icon: Icon(
                      Icons.pause,
                      color: AstraColors.textPrimary,
                      size: 25,
                    ),
                    onPressed: () {
                      // Handle pause functionality
                    },
                  ),
                  SizedBox(width: 10),
                  _bottomButton(
                    bgColor: AstraColors.errorVibrantColor,
                    icon: Icon(
                      Icons.close,
                      color: AstraColors.errorDarkColor,
                      size: 25,
                    ),
                    onPressed: () {
                      context.read<SessionCubit>().stopSession();
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            BlocBuilder<SessionCubit, SessionState>(
              buildWhen: (prev, next) => prev.visualizerAmplitude != next.visualizerAmplitude,
              builder: (context, state) {
                return VoiceVisualizer(amplitude: state.visualizerAmplitude);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomButton({
    double? width,
    double? height,
    required Color bgColor,
    required Widget icon,
    required VoidCallback onPressed,
    double? radius,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: height ?? 60,
        width: width ?? 60,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(radius ?? 30),
        ),
        child: Center(child: icon),
      ),
    );
  }

  Widget _buildSwitchCameraButton({required VoidCallback onTap}) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 10.0, bottom: 190),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AstraColors.background,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.flip_camera_android, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
