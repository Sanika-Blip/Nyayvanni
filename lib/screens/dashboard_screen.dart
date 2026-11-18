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
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final reports = context.read<ReportProvider>();
    final isSupervisor =
        context.read<AuthProvider>().user?.isSupervisor ?? false;
    await Future.wait([
      reports.loadDrafts(),
      if (isSupervisor) reports.loadReviewQueue(),
    ]);
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
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 40),
                children: [
                  _OfficerPanel(user: context.watch<AuthProvider>().user),
                  const SizedBox(height: 16),
                  const _SummaryStrip(),
                  const SizedBox(height: 16),
                  _RegisterPanel(
                    isSupervisor:
                        context.watch<AuthProvider>().user?.isSupervisor ??
                            false,
                    onNew: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NewReportScreen()),
                    ),
                    onOpen: (r, {required bool review}) async {
                      context.read<ReportProvider>().setCurrentReport(r);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ReportDetailScreen(reviewMode: review),
                        ),
                      );
                      if (mounted) _refresh();
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
      if (user?.isSupervisor == true) ('Role', 'Station supervisor'),
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
      ('Total', p.reports.length),
      ('Drafts', p.draftReports.length),
      ('In review', p.pendingReports.length),
      ('Approved', p.approvedReports.length),
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
              if (i > 0)
                const VerticalDivider(width: 1, color: AppTheme.divider),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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

// ── Register of FIR drafts (search, filter, supervisor queue) ───────────────

enum _Filter { all, draft, returned, inReview, approved }

class _RegisterPanel extends StatefulWidget {
  final bool isSupervisor;
  final VoidCallback onNew;
  final Future<void> Function(PoliceReport, {required bool review}) onOpen;
  const _RegisterPanel({
    required this.isSupervisor,
    required this.onNew,
    required this.onOpen,
  });

  @override
  State<_RegisterPanel> createState() => _RegisterPanelState();
}

class _RegisterPanelState extends State<_RegisterPanel> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;
  bool _newestFirst = true;
  bool _showQueue = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matchesFilter(PoliceReport r) {
    switch (_filter) {
      case _Filter.all:
        return true;
      case _Filter.draft:
        return r.reviewStatus == 'none';
      case _Filter.returned:
        return r.isReturned;
      case _Filter.inReview:
        return r.isPending;
      case _Filter.approved:
        return r.isApproved;
    }
  }

  bool _matchesQuery(PoliceReport r) {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      r.reportNumber,
      r.complainantName,
      r.natureOfOffence,
      r.placeOfOccurrence,
      r.officerName,
    ].any((s) => s.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportProvider>();
    final wide = MediaQuery.of(context).size.width >= 640;
    final source = _showQueue ? provider.reviewQueue : provider.reports;
    final rows = source
        .where((r) => _showQueue || _matchesFilter(r))
        .where(_matchesQuery)
        .toList()
      ..sort((a, b) => _newestFirst
          ? b.updatedAt.compareTo(a.updatedAt)
          : a.updatedAt.compareTo(b.updatedAt));

    return _Panel(
      title: _showQueue ? 'Review queue' : 'FIR drafts',
      trailing: SizedBox(
        height: 34,
        child: ElevatedButton.icon(
          onPressed: widget.onNew,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('New statement'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            textStyle: GoogleFonts.notoSans(
                fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.isSupervisor) _tabs(provider.reviewQueue.length),
          _toolbar(),
          if (provider.isLoading && source.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _emptyText(source.isEmpty),
                style: GoogleFonts.notoSans(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            )
          else ...[
            if (wide) _TableHead(showOfficer: _showQueue),
            for (var i = 0; i < rows.length; i++)
              _ReportRow(
                report: rows[i],
                wide: wide,
                last: i == rows.length - 1,
                showOfficer: _showQueue,
                unsynced: !_showQueue && provider.isUnsynced(rows[i].id),
                onTap: () => widget.onOpen(rows[i], review: _showQueue),
                onDelete: _showQueue || rows[i].isLocked
                    ? null
                    : () => context
                        .read<ReportProvider>()
                        .deleteReport(rows[i].id),
              ),
          ],
        ],
      ),
    );
  }

  String _emptyText(bool sourceEmpty) {
    if (_showQueue) {
      return sourceEmpty
          ? 'No FIRs are waiting for your review.'
          : 'No FIRs match your search.';
    }
    return sourceEmpty
        ? 'No FIR drafts have been recorded yet. Choose “New statement” to record a complainant’s account.'
        : 'No FIR drafts match your search or filter.';
  }

  Widget _tabs(int queueCount) {
    Widget tab(String label, bool selected, VoidCallback onTap) => InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? AppTheme.accent : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Text(
              label,
              style: GoogleFonts.notoSans(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppTheme.primaryDark : AppTheme.textSecondary,
              ),
            ),
          ),
        );
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
      ),
      child: Row(
        children: [
          tab('My drafts', !_showQueue,
              () => setState(() => _showQueue = false)),
          tab('Review queue ($queueCount)', _showQueue,
              () => setState(() => _showQueue = true)),
        ],
      ),
    );
  }

  Widget _toolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.notoSans(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search number, complainant, offence, place',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () => setState(_search.clear),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () => setState(() => _newestFirst = !_newestFirst),
                icon: Icon(
                  _newestFirst ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 16,
                ),
                label: Text(_newestFirst ? 'Newest' : 'Oldest'),
              ),
            ],
          ),
          if (!_showQueue) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final (f, label) in const [
                  (_Filter.all, 'All'),
                  (_Filter.draft, 'Draft'),
                  (_Filter.returned, 'Returned'),
                  (_Filter.inReview, 'In review'),
                  (_Filter.approved, 'Approved'),
                ])
                  ChoiceChip(
                    label: Text(label, style: const TextStyle(fontSize: 12)),
                    selected: _filter == f,
                    visualDensity: VisualDensity.compact,
                    selectedColor: AppTheme.primaryLight,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.divider),
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TableHead extends StatelessWidget {
  final bool showOfficer;
  const _TableHead({required this.showOfficer});

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
        border: Border(
          top: BorderSide(color: AppTheme.divider),
          bottom: BorderSide(color: AppTheme.divider),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 26, child: Text('Report no.', style: s)),
          Expanded(flex: 26, child: Text('Nature of offence', style: s)),
          Expanded(
              flex: 20,
              child: Text(showOfficer ? 'Recorded by' : 'Complainant',
                  style: s)),
          Expanded(flex: 14, child: Text('Updated', style: s)),
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
  final bool showOfficer;
  final bool unsynced;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _ReportRow({
    required this.report,
    required this.wide,
    required this.last,
    required this.showOfficer,
    required this.unsynced,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final offence = report.natureOfOffence.isNotEmpty
        ? report.natureOfOffence
        : (report.summary.isNotEmpty ? report.summary : '—');
    final who = showOfficer
        ? (report.officerName.isEmpty ? report.officerId : report.officerName)
        : (report.complainantName.trim().isEmpty
            ? '—'
            : report.complainantName);
    final date = _date(report.updatedAt);
    final number = GoogleFonts.notoSans(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppTheme.primary,
    );
    final body =
        GoogleFonts.notoSans(fontSize: 13, color: AppTheme.textPrimary);
    final muted =
        GoogleFonts.notoSans(fontSize: 12, color: AppTheme.textMuted);

    final content = wide
        ? Row(
            children: [
              Expanded(
                flex: 26,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.reportNumber,
                        style: number, overflow: TextOverflow.ellipsis),
                    if (unsynced) const SyncTag(),
                  ],
                ),
              ),
              Expanded(
                  flex: 26,
                  child: Text(offence,
                      style: body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis)),
              Expanded(
                  flex: 20,
                  child:
                      Text(who, style: body, overflow: TextOverflow.ellipsis)),
              Expanded(flex: 14, child: Text(date, style: muted)),
              Expanded(
                flex: 14,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ReportStatusBadge(report: report),
                ),
              ),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(report.reportNumber, style: number)),
                  ReportStatusBadge(report: report),
                ],
              ),
              const SizedBox(height: 4),
              Text(offence,
                  style: body, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text('$who  •  $date', style: muted),
              if (unsynced) const SyncTag(),
            ],
          );

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 12, onDelete == null ? 16 : 4, 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.divider)),
        ),
        child: Row(
          children: [
            Expanded(child: content),
            if (onDelete != null)
              IconButton(
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline,
                    color: AppTheme.textMuted, size: 20),
                onPressed: () => _confirmDelete(context),
              )
            else if (wide)
              const SizedBox(width: 24),
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
    if (ok == true) onDelete?.call();
  }

  String _date(DateTime dt) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }
}
