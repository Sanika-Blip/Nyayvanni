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
    final gutter = contentGutter(context, maxWidth: 880);
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          _TopBar(
            onProfile: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            onSignOut: () => context.read<AuthProvider>().logout(),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: () => context.read<ReportProvider>().loadDrafts(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 40),
                children: [
                  _OfficerPanel(user: context.watch<AuthProvider>().user),
                  const SizedBox(height: 16),
                  const _SummaryStrip(),
                  const SizedBox(height: 16),
                  _RegisterPanel(
                    onNew: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NewReportScreen()),
                    ),
                    onOpen: (r) {
                      context.read<ReportProvider>().setCurrentReport(r);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ReportDetailScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onProfile;
  final VoidCallback onSignOut;
  const _TopBar({required this.onProfile, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 600;
    final style = TextButton.styleFrom(foregroundColor: Colors.white);
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.primaryDark,
        border: Border(bottom: BorderSide(color: AppTheme.accent, width: 3)),
      ),
      padding: EdgeInsets.fromLTRB(
        contentGutter(context, maxWidth: 880),
        MediaQuery.of(context).padding.top + 10,
        contentGutter(context, maxWidth: 880) - 8,
        10,
      ),
      child: Row(
        children: [
          const NyayVaaniEmblem(size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NyayVanni',
                  style: GoogleFonts.notoSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                Text(
                  'Police Documentation System',
                  style: GoogleFonts.notoSans(
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          if (wide) ...[
            TextButton.icon(
              style: style,
              onPressed: onProfile,
              icon: const Icon(Icons.person_outline, size: 18),
              label: const Text('My profile'),
            ),
            TextButton.icon(
              style: style,
              onPressed: onSignOut,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign out'),
            ),
          ] else ...[
            IconButton(
              tooltip: 'My profile',
              onPressed: onProfile,
              icon: const Icon(Icons.person_outline, color: Colors.white),
            ),
            IconButton(
              tooltip: 'Sign out',
              onPressed: onSignOut,
              icon: const Icon(Icons.logout, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shared panel chrome: titled box like a form section ─────────────────────

class _Panel extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;
  const _Panel({required this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF7F8FA),
              border: Border(bottom: BorderSide(color: AppTheme.divider)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.notoSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryDark,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ── Officer details ──────────────────────────────────────────────────────────

class _OfficerPanel extends StatelessWidget {
  final dynamic user;
  const _OfficerPanel({required this.user});

  @override
  Widget build(BuildContext context) {
    String v(String? s) => (s == null || s.trim().isEmpty) ? '—' : s;
    final items = <(String, String)>[
      ('Name', v(user?.fullName)),
      ('Rank', v(user?.rank)),
      ('Officer ID', v(user?.officerId)),
      ('Police station', v(user?.station)),
      ('District', v(user?.district)),
    ];
    return _Panel(
      title: 'Officer on duty',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 32,
          runSpacing: 14,
          children: [
            for (final (label, value) in items)
              SizedBox(
                width: 150,
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
    );
  }
}

// ── Counts ───────────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ReportProvider>();
    final cells = <(String, int)>[
      ('Total drafts', p.reports.length),
      ('In progress', p.draftReports.length),
      ('Finalised', p.submittedReports.length),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.divider),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0) const VerticalDivider(width: 1, color: AppTheme.divider),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cells[i].$1,
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${cells[i].$2}',
                        style: GoogleFonts.notoSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Register of FIR drafts ───────────────────────────────────────────────────

class _RegisterPanel extends StatelessWidget {
  final VoidCallback onNew;
  final void Function(PoliceReport) onOpen;
  const _RegisterPanel({required this.onNew, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportProvider>();
    final wide = MediaQuery.of(context).size.width >= 640;
    return _Panel(
      title: 'FIR drafts',
      trailing: SizedBox(
        height: 34,
        child: ElevatedButton.icon(
          onPressed: onNew,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New statement'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            textStyle: GoogleFonts.notoSans(
                fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      child: Builder(builder: (context) {
        if (provider.isLoading && provider.reports.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (provider.reports.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'No FIR drafts have been recorded yet. Choose “New statement” to record a complainant’s account.',
              style: GoogleFonts.notoSans(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          );
        }
        return Column(
          children: [
            if (wide) const _TableHead(),
            for (var i = 0; i < provider.reports.length; i++)
              _ReportRow(
                report: provider.reports[i],
                wide: wide,
                last: i == provider.reports.length - 1,
                onTap: () => onOpen(provider.reports[i]),
                onDelete: () => context
                    .read<ReportProvider>()
                    .deleteReport(provider.reports[i].id),
              ),
          ],
        );
      }),
    );
  }
}

class _TableHead extends StatelessWidget {
  const _TableHead();

  @override
  Widget build(BuildContext context) {
    final s = GoogleFonts.notoSans(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppTheme.textMuted,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: [
          Expanded(flex: 26, child: Text('Report no.', style: s)),
          Expanded(flex: 26, child: Text('Nature of offence', style: s)),
          Expanded(flex: 20, child: Text('Complainant', style: s)),
          Expanded(flex: 14, child: Text('Date', style: s)),
          Expanded(flex: 14, child: Text('Status', style: s)),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final PoliceReport report;
  final bool wide;
  final bool last;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ReportRow({
    required this.report,
    required this.wide,
    required this.last,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final offence = report.natureOfOffence.isNotEmpty
        ? report.natureOfOffence
        : (report.summary.isNotEmpty ? report.summary : '—');
    final complainant =
        report.complainantName.trim().isEmpty ? '—' : report.complainantName;
    final date = _date(report.createdAt);
    final number = GoogleFonts.notoSans(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppTheme.primary,
    );
    final body = GoogleFonts.notoSans(
      fontSize: 13,
      color: AppTheme.textPrimary,
    );
    final muted = GoogleFonts.notoSans(
      fontSize: 12,
      color: AppTheme.textMuted,
    );

    final content = wide
        ? Row(
            children: [
              Expanded(
                  flex: 26,
                  child: Text(report.reportNumber,
                      style: number, overflow: TextOverflow.ellipsis)),
              Expanded(
                  flex: 26,
                  child: Text(offence,
                      style: body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis)),
              Expanded(
                  flex: 20,
                  child: Text(complainant,
                      style: body, overflow: TextOverflow.ellipsis)),
              Expanded(flex: 14, child: Text(date, style: muted)),
              Expanded(
                  flex: 14,
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: StatusBadge(status: report.status))),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(report.reportNumber, style: number)),
                  StatusBadge(status: report.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(offence,
                  style: body, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('$complainant  •  $date', style: muted),
            ],
          );

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppTheme.divider)),
        ),
        child: Row(
          children: [
            Expanded(child: content),
            IconButton(
              tooltip: 'Delete',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline,
                  color: AppTheme.textMuted, size: 20),
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this draft?'),
        content: Text(
            '${report.reportNumber} will be permanently removed. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) onDelete();
  }

  String _date(DateTime dt) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }
}
