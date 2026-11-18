import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const AuthGate(),
            transitionsBuilder: (_, anim, __, child) => FadeTransition(
              opacity: anim,
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF2F4F7),
              Color(0xFFE9EDF2),
              Color(0xFFF2F4F7),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background decorations
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withOpacity(0.06),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -60,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.secondary.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.3,
              left: -40,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent.withOpacity(0.08),
                ),
              ),
            ),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: _buildLogo(),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Title
                  SlideTransition(
                    position: _slideAnim,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: _buildTitle(),
                    ),
                  ),
                  const SizedBox(height: 60),

                  // Loading indicator
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: _buildLoader(),
                  ),
                ],
              ),
            ),

            // Bottom
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    Text(
                      'Speak your complaint.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Get a structured FIR draft.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.35),
            blurRadius: 36,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 20,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const Icon(
            Icons.local_police,
            color: Colors.white,
            size: 44,
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'NyayVanni',
          style: GoogleFonts.inter(
            fontSize: 38,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'न्यायवाणी',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w400,
            color: AppTheme.textSecondary,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primaryLight.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Voice-to-text FIR drafting',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoader() {
    return Column(
      children: [
        SizedBox(
          width: 140,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              backgroundColor: AppTheme.primaryLight.withOpacity(0.3),
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppTheme.primary.withOpacity(0.7)),
              minHeight: 3,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Preparing your FIR assistant...',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}