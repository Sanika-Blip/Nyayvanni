import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _rank = TextEditingController();
  final _badge = TextEditingController();
  final _station = TextEditingController();
  final _district = TextEditingController();
  final _state = TextEditingController(text: 'Maharashtra');
  final _address = TextEditingController();
  List<Map<String, dynamic>> _stations = [];

  @override
  void initState() {
    super.initState();
    ApiService.fetchStations().then((list) {
      if (mounted) setState(() => _stations = list);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _rank.dispose();
    _badge.dispose();
    _station.dispose();
    _district.dispose();
    _state.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and email are required')),
      );
      return;
    }
    try {
      final message = await context.read<AuthProvider>().register({
        'fullName': _name.text,
        'email': _email.text,
        'phone': _phone.text,
        'rank': _rank.text,
        'badgeNumber': _badge.text,
        'station': _station.text,
        'district': _district.text,
        'state': _state.text,
        'address': _address.text,
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Submitted'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiService.describe(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AuthProvider>().busy;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Officer registration',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Your request goes to the admin panel. After approval, your officer ID and password are sent to this email.',
            style: GoogleFonts.inter(
                fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 18),
          GlassCard(
            child: Column(
              children: [
                NyayaTextField(
                    label: 'Full name',
                    controller: _name,
                    prefixIcon: Icons.person_outline),
                const SizedBox(height: 12),
                NyayaTextField(
                    label: 'Official email',
                    controller: _email,
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                NyayaTextField(
                    label: 'Phone',
                    controller: _phone,
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                NyayaTextField(
                    label: 'Rank',
                    controller: _rank,
                    hint: 'e.g. Inspector',
                    prefixIcon: Icons.military_tech_outlined),
                const SizedBox(height: 12),
                NyayaTextField(
                    label: 'Badge number',
                    controller: _badge,
                    prefixIcon: Icons.badge_outlined),
                const SizedBox(height: 12),
                NyayaTextField(
                    label: 'Police station',
                    controller: _station,
                    prefixIcon: Icons.location_city_outlined),
                if (_stations.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _stations
                        .map((s) => ActionChip(
                              label: Text(s['name'] as String? ?? ''),
                              onPressed: () {
                                _station.text = s['name'] as String? ?? '';
                                _district.text = s['district'] as String? ?? '';
                                _state.text = s['state'] as String? ?? _state.text;
                                setState(() {});
                              },
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 12),
                NyayaTextField(
                    label: 'District',
                    controller: _district,
                    prefixIcon: Icons.map_outlined),
                const SizedBox(height: 12),
                NyayaTextField(
                    label: 'State',
                    controller: _state,
                    prefixIcon: Icons.public),
                const SizedBox(height: 12),
                NyayaTextField(
                    label: 'Address',
                    controller: _address,
                    prefixIcon: Icons.home_outlined,
                    maxLines: 2),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: busy ? null : _submit,
            child: Text(busy ? 'Submitting…' : 'Submit to admin'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
