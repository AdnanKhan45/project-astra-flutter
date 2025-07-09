
import 'package:flutter/material.dart';
import 'package:project_astra_flutter/const/app_colors.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: Image.asset(
            "assets/images/background.webp",
            fit: BoxFit.cover,
          ),
        ),

        Align(
          alignment: Alignment.center,
          child: CircularProgressIndicator(
            color: AstraColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
