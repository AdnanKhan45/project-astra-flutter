import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:project_astra_flutter/const/app_colors.dart';
import 'package:project_astra_flutter/controller/session_cubit.dart';
import 'package:project_astra_flutter/controller/session_state.dart';
import 'package:project_astra_flutter/ui/session_page.dart';
import 'package:project_astra_flutter/widgets/gradient_text.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AstraColors.background,
      body: Stack(
        children: [
          // Build Background
          _background(),

          // Build Welcome Text
          _welcomeText(),

          // Build Get Started Button
          _getStartedButton(context),
        ],
      ),
    );
  }

  Widget _background() {
    return Positioned.fill(
      child: Image.asset("assets/images/background.webp", fit: BoxFit.cover),
    );
  }

  Widget _welcomeText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 50),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            child: Text(
              "Welcome to",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 40,
                height: 1,
                fontWeight: FontWeight.bold,
                color: AstraColors.textPrimary,
              ),
            ),
          ),
          GradientText(
            "Project Astra",
            gradient: LinearGradient(
              colors: [AstraColors.primary, AstraColors.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: AstraColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            padding: EdgeInsets.all(5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AstraColors.border, width: 1),
            ),
            child: Text(
              "EXP Flutter",
              style: TextStyle(fontSize: 10, color: AstraColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getStartedButton(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child:  Container(
        width: 150,
        margin: EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AstraColors.primary, AstraColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BlocProvider(
                  create: (context) => SessionCubit(),
                  child: SessionPage(),
                ),
              ),
            );
          },
          child: Text(
            "Get Started",
            style: TextStyle(
              fontSize: 20,
              color: AstraColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
