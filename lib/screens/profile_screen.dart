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
  late final TextEditingController _phone;
  late final TextEditingController _address;
  final _currentPw = TextEditingController();
  final _newPw = TextEditingController();
  final _confirmPw = TextEditingController();
  String? _pwError;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthProvider>().user!;
    _phone = TextEditingController(text: u.phone);
    _address = TextEditingController(text: u.address);
  }

  @override
  void dispose() {
    _phone.dispose();
    _address.dispose();
    _currentPw.dispose();
    _newPw.dispose();
    _confirmPw.dispose();
    super.dispose();
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppTheme.error : AppTheme.success,
      ),
    );
  }

  Future<void> _saveContact() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.updateProfile({
      'phone': _phone.text.trim(),
      'address': _address.text.trim(),
    });
    if (!mounted) return;
    ok
        ? _toast('Contact details saved.')
        : _toast(auth.error ?? 'Could not save. Please try again.',
            error: true);
  }

  Future<void> _changePassword() async {
    final auth = context.read<AuthProvider>();
    if (_currentPw.text.isEmpty) {
      setState(() => _pwError = 'Enter your current password.');
      return;
    }
    if (_newPw.text.length < 8) {
      setState(() => _pwError = 'The new password must be at least 8 characters.');
      return;
    }
    if (_newPw.text != _confirmPw.text) {
      setState(() => _pwError = 'The new passwords do not match.');
      return;
    }
    setState(() => _pwError = null);
    final ok = await auth.updateProfile({
      'currentPassword': _currentPw.text,
      'password': _newPw.text,
    });
    if (!mounted) return;
    if (ok) {
      _currentPw.clear();
      _newPw.clear();
      _confirmPw.clear();
      _toast('Password changed.');
    } else {
      setState(() => _pwError = auth.error ?? 'Could not change the password.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final u = auth.user!;
    final gutter = contentGutter(context, maxWidth: 720);
    final wide = MediaQuery.of(context).size.width >= 640;

    String v(String s) => s.trim().isEmpty ? '—' : s;
    final service = <(String, String)>[
      ('Officer ID', v(u.officerId)),
      ('Badge number', v(u.badgeNumber)),
      ('Rank', v(u.rank)),
      ('Police station', v(u.station)),
      ('District', v(u.district)),
      ('State', v(u.state)),
      ('Official email', v(u.email)),
      ('Account status', u.status == 'active' ? 'Active' : 'Disabled'),
    ];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('My profile')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 40),
        children: [
          // Identity card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppTheme.primaryDark,
              borderRadius: BorderRadius.all(Radius.circular(4)),
              border: Border(
                bottom: BorderSide(color: AppTheme.accent, width: 3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.accent, width: 1.5),
                  ),
                  child: Text(
                    u.initials,
                    style: GoogleFonts.notoSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.fullName,
                        style: GoogleFonts.notoSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (u.rank.isNotEmpty) u.rank,
                          if (u.station.isNotEmpty) u.station,
                        ].join('  |  '),
                        style: GoogleFonts.notoSans(
                          fontSize: 13,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Service details (read-only)
          FormPanel(
            title: 'Service details',
            subtitle:
                'Maintained by your administrator. Contact them to correct any of these.',
            child: Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                for (final (label, value) in service)
                  SizedBox(
                    width: wide
                        ? 300
                        : (label == 'Official email' || label == 'Police station')
                            ? double.infinity
                            : (MediaQuery.of(context).size.width - 40 - 32 - 24) / 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.notoSans(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value,
                          style: GoogleFonts.notoSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Contact details (editable)
          FormPanel(
            title: 'Contact details',
            subtitle: 'You can update your phone number and address.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NyayaTextField(
                  label: 'Phone number',
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),
                NyayaTextField(
                  label: 'Address',
                  controller: _address,
                  maxLines: 2,
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: auth.busy ? null : _saveContact,
                  child: Text(auth.busy ? 'Saving…' : 'Save contact details'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Password
          FormPanel(
            title: 'Change password',
            subtitle: 'Use at least 8 characters.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NyayaTextField(
                  label: 'Current password',
                  controller: _currentPw,
                  obscureText: true,
                ),
                const SizedBox(height: 14),
                NyayaTextField(
                  label: 'New password',
                  controller: _newPw,
                  obscureText: true,
                ),
                const SizedBox(height: 14),
                NyayaTextField(
                  label: 'Confirm new password',
                  controller: _confirmPw,
                  obscureText: true,
                ),
                if (_pwError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _pwError!,
                    style: GoogleFonts.notoSans(
                      fontSize: 13,
                      color: AppTheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: auth.busy ? null : _changePassword,
                  child: const Text('Update password'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.read<AuthProvider>().logout();
              },
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.error,
                side: const BorderSide(color: AppTheme.error),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
