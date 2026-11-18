import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';
import '../models/report_model.dart';
import '../models/report_provider.dart';
import '../models/auth_provider.dart';
import '../widgets/common_widgets.dart';
import 'report_detail_screen.dart';

class NewReportScreen extends StatefulWidget {
  const NewReportScreen({super.key});

  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends State<NewReportScreen>
    with TickerProviderStateMixin {
  // Controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _stationCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _transcriptCtrl = TextEditingController();

  // State
  Language _selectedLanguage = Language.auto;
  bool _isRecording = false;
  bool _isProcessing = false;
  double _soundLevel = 0.0;
  double _confidence = 0.0;
  String _statusText = 'Tap to start recording';

  // Speech
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;

  // Animation
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  int _currentStep = 0; // 0 = setup, 1 = recording, 2 = review

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initSpeech();
    final officer = context.read<AuthProvider>().user;
    if (officer != null) {
      _stationCtrl.text = officer.station;
      _districtCtrl.text = officer.district;
    }
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _fadeController.forward();
  }

  Future<void> _initSpeech() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      _speechAvailable = await _speech.initialize(
        onError: (error) {
          setState(() {
            _statusText = 'Error: ${error.errorMsg}';
            _isRecording = false;
          });
          _pulseController.stop();
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (_isRecording) _stopRecording();
          }
        },
      );
      setState(() {});
    } else {
      setState(() => _statusText = 'Microphone permission required');
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (!_speechAvailable) {
      _showSnackBar('Speech recognition not available on this device');
      return;
    }

    setState(() {
      _isRecording = true;
      _statusText = 'Listening... speak clearly';
    });

    _pulseController.repeat(reverse: true);

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _transcriptCtrl.text = result.recognizedWords;
          _confidence = result.confidence;
          if (result.finalResult) {
            _statusText = 'Processing complete';
          }
        });
      },
      onSoundLevelChange: (level) {
        setState(() => _soundLevel = level);
      },
      localeId: _selectedLanguage.code.isEmpty ? null : _selectedLanguage.code,
      listenFor: const Duration(minutes: 5),
      pauseFor: const Duration(seconds: 8),
      partialResults: true,
      cancelOnError: false,
    );
  }

  Future<void> _stopRecording() async {
    await _speech.stop();
    _pulseController.stop();
    _pulseController.reset();

    setState(() {
      _isRecording = false;
      _statusText = _transcriptCtrl.text.isNotEmpty
          ? 'Recording complete. Review below.'
          : 'No speech detected. Try again.';
    });

    if (_transcriptCtrl.text.isNotEmpty) {
      setState(() => _currentStep = 2);
    }
  }

  Future<void> _generateReport() async {
    if (_transcriptCtrl.text.trim().isEmpty) {
      _showSnackBar('Please record some speech first');
      return;
    }

    setState(() => _isProcessing = true);

    final provider = context.read<ReportProvider>();
    final officer = context.read<AuthProvider>().user;
    provider.createNewReport(
      language: _selectedLanguage,
      complainantName: _nameCtrl.text,
      complainantPhone: _phoneCtrl.text,
      complainantAddress: _addressCtrl.text,
      station: _stationCtrl.text,
      district: _districtCtrl.text,
      officerId: officer?.officerId ?? '',
      officerName: officer?.fullName ?? '',
      badgeNumber: officer?.badgeNumber ?? officer?.officerId ?? '',
    );

    provider.updateTranscript(_transcriptCtrl.text, _confidence);
    await provider.generateStructuredReport(_transcriptCtrl.text);
    await provider.saveReport(status: ReportStatus.draft);

    if (mounted) {
      setState(() => _isProcessing = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ReportDetailScreen()),
      );
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.nunito()),
        backgroundColor: AppTheme.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _pulseController.dispose();
    _fadeController.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _stationCtrl.dispose();
    _districtCtrl.dispose();
    _transcriptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildStepIndicator(),
                    const SizedBox(height: 28),
                    if (_currentStep == 0) ...[
                      _buildSetupSection(),
                      const SizedBox(height: 24),
                      _buildLanguageSelector(),
                      const SizedBox(height: 32),
                      _buildStartButton(),
                    ] else if (_currentStep == 1) ...[
                      _buildRecordingSection(),
                    ] else ...[
                      _buildReviewSection(),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppTheme.background,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.arrow_back_ios_new,
              size: 16, color: AppTheme.textPrimary),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'New FIR draft',
        style: GoogleFonts.playfairDisplay(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Setup', 'Record', 'Review'];
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i == _currentStep;
          final isCompleted = i < _currentStep;
          return Expanded(
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (i <= _currentStep) setState(() => _currentStep = i);
                  },
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? AppTheme.success
                              : isActive
                                  ? AppTheme.primary
                                  : AppTheme.divider,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isCompleted
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 16)
                              : Text(
                                  '${i + 1}',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isActive
                                        ? Colors.white
                                        : AppTheme.textMuted,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        steps[i],
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w400,
                          color: isActive
                              ? AppTheme.primary
                              : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppTheme.success.withOpacity(0.5)
                            : AppTheme.divider,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSetupSection() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your details (optional)',
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You can skip this and we will try to pick your name from what you say.',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          NyayaTextField(
            label: 'Your name',
            controller: _nameCtrl,
            prefixIcon: Icons.person_outline,
          ),
          const SizedBox(height: 14),
          NyayaTextField(
            label: 'Phone number',
            controller: _phoneCtrl,
            prefixIcon: Icons.phone_outlined,
          ),
          const SizedBox(height: 14),
          NyayaTextField(
            label: 'Address',
            controller: _addressCtrl,
            prefixIcon: Icons.home_outlined,
            maxLines: 2,
          ),
          const SizedBox(height: 14),
          NyayaTextField(
            label: 'Police station (if known)',
            controller: _stationCtrl,
            prefixIcon: Icons.location_city_outlined,
          ),
          const SizedBox(height: 14),
          NyayaTextField(
            label: 'District',
            controller: _districtCtrl,
            prefixIcon: Icons.map_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Language',
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose Hindi, Marathi, or English — or let the device detect it',
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Language.values.map((lang) {
              return LanguageChip(
                language: lang,
                isSelected: _selectedLanguage == lang,
                onTap: () => setState(() => _selectedLanguage = lang),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => setState(() => _currentStep = 1),
        icon: const Icon(Icons.mic),
        label: const Text('Start speaking'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingSection() {
    return Column(
      children: [
        // Recording card
        GlassCard(
          child: Column(
            children: [
              // Language indicator
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.language,
                        size: 14, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${_selectedLanguage.nativeName} • FIR draft',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Mic button
              _buildMicButton(),
              const SizedBox(height: 28),

              // Waveform
              AudioWaveform(
                isActive: _isRecording,
                color: _isRecording ? AppTheme.accent : AppTheme.textMuted,
              ),
              const SizedBox(height: 20),

              // Status text
              Text(
                _statusText,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: _isRecording
                      ? AppTheme.primaryDark
                      : AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),

              if (_isRecording) ...[
                const SizedBox(height: 8),
                _buildSoundLevelBar(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Live transcript
        if (_transcriptCtrl.text.isNotEmpty) _buildLiveTranscript(),
      ],
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: _toggleRecording,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (_, child) {
          return Transform.scale(
            scale: _isRecording ? _pulseAnimation.value : 1.0,
            child: child,
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow
            if (_isRecording)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accent.withOpacity(0.15),
                ),
              ),
            // Middle ring
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording
                    ? AppTheme.accent.withOpacity(0.2)
                    : AppTheme.primaryLight.withOpacity(0.3),
              ),
            ),
            // Main button
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _isRecording
                    ? AppTheme.recordingGradient
                    : AppTheme.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording ? AppTheme.accent : AppTheme.primary)
                        .withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundLevelBar() {
    final normalized = ((_soundLevel + 10) / 20).clamp(0.0, 1.0);
    return Column(
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.volume_up, size: 14, color: AppTheme.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: normalized,
                  backgroundColor: AppTheme.divider,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.accent),
                  minHeight: 6,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLiveTranscript() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isRecording ? AppTheme.success : AppTheme.textMuted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isRecording ? 'Live Transcript' : 'Recorded Transcript',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              if (_confidence > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (_confidence > 0 && _confidence < 0.7)
                        ? AppTheme.warning.withOpacity(0.2)
                        : AppTheme.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${(_confidence * 100).toInt()}% accurate',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: (_confidence > 0 && _confidence < 0.7)
                          ? const Color(0xFFB8860B)
                          : AppTheme.success,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _transcriptCtrl,
              maxLines: null,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: AppTheme.textPrimary,
                height: 1.6,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Transcript will appear here...',
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _transcriptCtrl.clear();
                    setState(() => _confidence = 0.0);
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _transcriptCtrl.text.isNotEmpty
                      ? () => setState(() => _currentStep = 2)
                      : null,
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: const Text('Review text'),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection() {
    return Column(
      children: [
        // Header card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Transcript ready',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Review & Generate',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your speech has been converted to text. Check it, then generate the FIR draft.',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Report meta
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report Summary',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              _ReviewRow(
                  icon: Icons.description_outlined,
                  label: 'Document',
                  value: 'FIR draft'),
              _ReviewRow(
                  icon: Icons.language,
                  label: 'Language',
                  value: _selectedLanguage.name),
              _ReviewRow(
                  icon: Icons.person_outline,
                  label: 'Complainant',
                  value: _nameCtrl.text.isEmpty ? 'From narration' : _nameCtrl.text),
              _ReviewRow(
                  icon: Icons.location_city_outlined,
                  label: 'Station',
                  value: _stationCtrl.text.isEmpty ? 'Not set' : _stationCtrl.text),
              if (_confidence > 0)
                _ReviewRow(
                  icon: Icons.insights,
                  label: 'Accuracy',
                  value: '${(_confidence * 100).toInt()}%',
                  valueColor: _confidence < 0.7
                      ? AppTheme.warning
                      : AppTheme.success,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Transcript
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recorded Transcript',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _transcriptCtrl.text.isNotEmpty
                      ? _transcriptCtrl.text
                      : 'No transcript available',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => setState(() => _currentStep = 1),
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('Edit Transcript'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Generate button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _generateReport,
            icon: _isProcessing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.auto_fix_high),
            label: Text(
                _isProcessing ? 'Generating...' : 'Generate FIR draft'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => setState(() => _currentStep = 1),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AppTheme.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: Text(
              'Re-record',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _ReviewRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 13,
              color: AppTheme.textMuted,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}