import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/auth_provider.dart';
import '../widgets/common_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _rank;
  late final TextEditingController _badge;
  late final TextEditingController _station;
  late final TextEditingController _district;
  late final TextEditingController _state;
  late final TextEditingController _address;
  late final TextEditingController _password;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthProvider>().user!;
    _name = TextEditingController(text: u.fullName);
    _phone = TextEditingController(text: u.phone);
    _rank = TextEditingController(text: u.rank);
    _badge = TextEditingController(text: u.badgeNumber);
    _station = TextEditingController(text: u.station);
    _district = TextEditingController(text: u.district);
    _state = TextEditingController(text: u.state);
    _address = TextEditingController(text: u.address);
    _password = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _rank.dispose();
    _badge.dispose();
    _station.dispose();
    _district.dispose();
    _state.dispose();
    _address.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final payload = <String, dynamic>{
      'fullName': _name.text,
      'phone': _phone.text,
      'rank': _rank.text,
      'badgeNumber': _badge.text,
      'station': _station.text,
      'district': _district.text,
      'state': _state.text,
      'address': _address.text,
    };
    if (_password.text.trim().isNotEmpty) {
      payload['password'] = _password.text.trim();
    }
    final ok = await context.read<AuthProvider>().updateProfile(payload);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Profile updated'
            : (context.read<AuthProvider>().error ?? 'Update failed')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final u = auth.user!;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('My profile',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Officer ID: ${u.officerId}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                Text(u.email,
                    style: GoogleFonts.inter(color: AppTheme.textMuted)),
                const SizedBox(height: 16),
                NyayaTextField(label: 'Full name', controller: _name),
                const SizedBox(height: 12),
                NyayaTextField(label: 'Phone', controller: _phone),
                const SizedBox(height: 12),
                NyayaTextField(label: 'Rank', controller: _rank),
                const SizedBox(height: 12),
                NyayaTextField(label: 'Badge number', controller: _badge),
                const SizedBox(height: 12),
                NyayaTextField(label: 'Station', controller: _station),
                const SizedBox(height: 12),
                NyayaTextField(label: 'District', controller: _district),
                const SizedBox(height: 12),
                NyayaTextField(label: 'State', controller: _state),
                const SizedBox(height: 12),
                NyayaTextField(
                    label: 'Address', controller: _address, maxLines: 2),
                const SizedBox(height: 12),
                NyayaTextField(
                  label: 'New password (optional)',
                  controller: _password,
                  obscureText: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: auth.busy ? null : _save,
            child: Text(auth.busy ? 'Saving…' : 'Save changes'),
          ),
        ],
      ),
    );
  }
}
