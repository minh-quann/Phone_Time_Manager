import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

class CelebrationPage extends StatelessWidget {
  final ConfettiController controller;

  const CelebrationPage({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chúc mừng')),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Chúc mừng! Bạn đã giữ thói quen tốt.', style: TextStyle(fontSize: 20)),
                SizedBox(height: 12),
                Text('Tiếp tục nhé.', style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: controller,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 40,
              emissionFrequency: 0.02,
              maxBlastForce: 20,
              minBlastForce: 5,
              gravity: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
