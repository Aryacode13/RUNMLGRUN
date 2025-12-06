import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  
  const SplashScreen({
    super.key,
    required this.nextScreen,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  int _loopCount = 0;
  static const int _maxLoops = 3; // Loop 3 kali sebelum navigasi

  @override
  void initState() {
    super.initState();
    
    // Setup animation controller
    // Duration 1 detik untuk fade in atau fade out
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000), // 1 detik untuk fade in/fade out
      vsync: this,
    );

    // Fade animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Listen to animation status untuk looping
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Fade in selesai (1 detik), mulai fade out
        _controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        // Fade out selesai (1 detik), cek apakah sudah cukup loop
        _loopCount++;
        if (_loopCount >= _maxLoops) {
          // Sudah cukup loop, navigasi ke next screen
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => widget.nextScreen),
              );
            }
          });
        } else {
          // Lanjutkan loop berikutnya (fade in lagi)
          _controller.forward();
        }
      }
    });

    // Start animation dengan fade in
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Image.asset(
            'lib/assets/RMR_W.png',
            width: MediaQuery.of(context).size.width * 0.6,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.image_not_supported,
                color: Colors.white,
                size: 100,
              );
            },
          ),
        ),
      ),
    );
  }
}

