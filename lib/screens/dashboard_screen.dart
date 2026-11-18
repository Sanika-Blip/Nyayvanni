import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../models/report_model.dart';
import '../models/report_provider.dart';
import '../models/auth_provider.dart';
import '../widgets/common_widgets.dart';
import 'new_report_screen.dart';
import 'report_detail_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportProvider>().loadDrafts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildStatsRow()),
          SliverToBoxAdapter(child: _buildQuickActions()),
          SliverToBoxAdapter(child: _buildRecentReports()),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      backgroundColor: AppTheme.background,
      elevation: 0,
      flexibleSpace: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 24,
          right: 24,
          bottom: 8,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'NyayVanni',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Profile',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
              icon: const Icon(Icons.person_outline, color: AppTheme.textPrimary),
            ),
            IconButton(
              tooltip: 'Sign out',
              onPressed: () async {
                await context.read<AuthProvider>().logout();
              },
              icon: const Icon(Icons.logout, color: AppTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final officer = context.watch<AuthProvider>().user;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            officer == null
                ? 'Duty officer'
                : '${officer.rank.isEmpty ? 'Officer' : officer.rank} ${officer.fullName}',
            style: GoogleFonts.inter(
              fontSize: 15,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            'Speak. Review. Draft an FIR.',
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            officer == null
                ? 'Hindi, Marathi, or English.'
                : '${officer.officerId}  •  ${officer.station.isEmpty ? 'Station not set' : officer.station}',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Row(
            children: [
              Expanded(
                child: StatCard(
                  value: provider.reports.length.toString(),
                  label: 'Drafts',
                  icon: Icons.description_outlined,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  value: provider.draftReports.length.toString(),
                  label: 'In progress',
                  icon: Icons.edit_outlined,
                  color: AppTheme.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  value: provider.submittedReports.length.toString(),
                  label: 'Finalised',
                  icon: Icons.verified_outlined,
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Start here',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          _QuickActionCard(
            icon: Icons.mic,
            label: 'Narrate your complaint',
            subtitle: 'Record in Hindi, Marathi, or English',
            gradient: AppTheme.primaryGradient,
            onTap: () => _openNewReport(context),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentReports() {
    return Consumer<ReportProvider>(
      builder: (context, provider, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Session drafts',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Kept on this device for demonstration and review.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              if (provider.reports.isEmpty)
                _buildEmptyState()
              else
                ...provider.reports.map(
                  (report) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ReportCard(
                      report: report,
                      onTap: () => _openReportDetail(context, report),
                      onDelete: () => context
                          .read<ReportProvider>()
                          .deleteReport(report.id),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return GlassCard(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic_none,
              size: 40,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No drafts yet',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the mic and tell what happened.\nWe will turn it into an FIR draft.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () => _openNewReport(context),
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.mic, color: Colors.white),
        label: Text(
          'New FIR draft',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  void _openNewReport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewReportScreen()),
    );
  }

  void _openReportDetail(BuildContext context, PoliceReport report) {
    context.read<ReportProvider>().setCurrentReport(report);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ReportDetailScreen()),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final PoliceReport report;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ReportCard({
    required this.report,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: report.isLowConfidence
                    ? AppTheme.warning.withOpacity(0.25)
                    : AppTheme.primaryLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                report.isLowConfidence
                    ? Icons.warning_amber_outlined
                    : Icons.description_outlined,
                color: report.isLowConfidence
                    ? const Color(0xFFB8860B)
                    : AppTheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          report.reportNumber,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      StatusBadge(status: report.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.summary.isNotEmpty
                        ? report.summary
                        : (report.natureOfOffence.isNotEmpty
                            ? report.natureOfOffence
                            : 'FIR draft'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const ReportTypeBadge(),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.access_time,
                        size: 11,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _formatDate(report.createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppTheme.textMuted, size: 20),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete draft?'),
                    content: const Text('This cannot be undone.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok == true) onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
