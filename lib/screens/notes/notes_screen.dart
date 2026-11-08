import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/note_model.dart';
import '../../providers/notes_provider.dart';
import '../../widgets/common/app_progress_bar.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesStreamProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes & Reminders'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: notesAsync.when(
              data: (notes) {
                final due = notes.where((n) => n.isReminderDue).length;
                if (due == 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.debitRed.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.debitRed.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_active_rounded,
                          size: 14, color: AppColors.debitRed),
                      const SizedBox(width: 4),
                      Text(
                        '$due due',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.debitRed,
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, st) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
      body: notesAsync.when(
        data: (notes) {
          if (notes.isEmpty) {
            return _EmptyState(onAdd: () => _showAddSheet(context, ref));
          }

          // Sort: due first, then upcoming reminders, then no reminders
          final due = notes.where((n) => n.isReminderDue).toList();
          final upcoming = notes.where((n) => n.isReminderUpcoming).toList();
          final plain = notes.where((n) => !n.hasReminder).toList();
          final sorted = [...due, ...upcoming, ...plain];

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 110),
            itemCount: sorted.length + (due.isNotEmpty ? 1 : 0),
            itemBuilder: (context, idx) {
              // Insert "🔔 Reminders Due" header
              if (due.isNotEmpty && idx == 0) {
                return _SectionHeader(
                  label: '🔔 Reminders Due',
                  color: AppColors.debitRed,
                );
              }
              final offset = due.isNotEmpty ? 1 : 0;
              final note = sorted[idx - offset];
              return _NoteCard(
                note: note,
                isDark: isDark,
                theme: theme,
                onTap: () => _showNoteSheet(context, ref, note),
              );
            },
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: AppProgressBar(),
          ),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error loading notes: $err'),
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90),
        child: FloatingActionButton.extended(
          heroTag: 'notes_add_fab',
          onPressed: () => _showAddSheet(context, ref),
          backgroundColor: AppColors.secondary,
          foregroundColor: AppColors.onSecondary,
          icon: const Icon(Icons.note_add_rounded, size: 20),
          label: const Text('Add Note',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _NoteEditSheet(
        ref: ref,
        onSave: (title, body, reminderDate) async {
          await ref
              .read(notesNotifierProvider.notifier)
              .addNote(title: title, body: body, reminderDate: reminderDate);
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _showNoteSheet(BuildContext context, WidgetRef ref, NoteModel note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _NoteViewSheet(
        note: note,
        ref: ref,
        onEdit: () {
          Navigator.of(ctx).pop();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx2) => _NoteEditSheet(
              ref: ref,
              existingNote: note,
              onSave: (title, body, reminderDate) async {
                await ref.read(notesNotifierProvider.notifier).updateNote(
                      note.copyWith(
                        title: title,
                        body: body,
                        reminderDate: reminderDate,
                      ),
                    );
                if (ctx2.mounted) Navigator.of(ctx2).pop();
              },
            ),
          );
        },
        onDelete: () async {
          Navigator.of(ctx).pop();
          await ref.read(notesNotifierProvider.notifier).deleteNote(note.id);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.isDark,
    required this.theme,
    required this.onTap,
  });

  final NoteModel note;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onTap;

  Color get _accentColor {
    if (note.isReminderDue) return AppColors.debitRed;
    if (note.isReminderUpcoming) return AppColors.warning;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = note.hasReminder
        ? _accentColor.withValues(alpha: 0.4)
        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      note.isReminderDue
                          ? Icons.notifications_active_rounded
                          : note.hasReminder
                              ? Icons.alarm_rounded
                              : Icons.sticky_note_2_rounded,
                      size: 16,
                      color: _accentColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    Formatters.relative(note.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (note.body.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  note.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
              if (note.hasReminder) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.alarm_rounded,
                          size: 11, color: _accentColor),
                      const SizedBox(width: 4),
                      Text(
                        note.isReminderDue
                            ? '⚠ Due: ${Formatters.date(note.reminderDate!)}'
                            : 'Reminder: ${Formatters.date(note.reminderDate!)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.sticky_note_2_rounded,
                size: 48,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Notes Yet',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Add notes to remember future orders,\nparts to buy, or anything important.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 160,
              child: ElevatedButton.icon(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                ),
                icon: const Icon(Icons.note_add_rounded, size: 18),
                label: const Text('Add Note',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// View Note Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _NoteViewSheet extends StatelessWidget {
  const _NoteViewSheet({
    required this.note,
    required this.ref,
    required this.onEdit,
    required this.onDelete,
  });

  final NoteModel note;
  final WidgetRef ref;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color accentColor = AppColors.primary;
    if (note.isReminderDue) accentColor = AppColors.debitRed;
    if (note.isReminderUpcoming) accentColor = AppColors.warning;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  note.isReminderDue
                      ? Icons.notifications_active_rounded
                      : Icons.sticky_note_2_rounded,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  note.title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 20),
                color: AppColors.primary,
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: AppColors.debitRed,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Note?'),
                      content: const Text('This note will be permanently deleted.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.debitRed,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(80, 40)),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            onDelete();
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
                tooltip: 'Delete',
              ),
            ],
          ),
          if (note.hasReminder) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.alarm_rounded, size: 13, color: accentColor),
                  const SizedBox(width: 6),
                  Text(
                    note.isReminderDue
                        ? '⚠ Reminder was due: ${Formatters.date(note.reminderDate!)}'
                        : 'Reminder: ${Formatters.date(note.reminderDate!)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (note.body.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              note.body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Created: ${Formatters.createdAtFull(note.createdAt)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add / Edit Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _NoteEditSheet extends ConsumerStatefulWidget {
  const _NoteEditSheet({
    required this.ref,
    required this.onSave,
    this.existingNote,
  });

  final WidgetRef ref;
  final Future<void> Function(String title, String body, DateTime? reminderDate)
      onSave;
  final NoteModel? existingNote;

  @override
  ConsumerState<_NoteEditSheet> createState() => _NoteEditSheetState();
}

class _NoteEditSheetState extends ConsumerState<_NoteEditSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  DateTime? _reminderDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.existingNote?.title ?? '');
    _bodyCtrl = TextEditingController(text: widget.existingNote?.body ?? '');
    _reminderDate = widget.existingNote?.reminderDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _reminderDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _reminderDate = picked);
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_titleCtrl.text, _bodyCtrl.text, _reminderDate);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEdit = widget.existingNote != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isEdit ? 'Edit Note' : 'New Note',
            style:
                theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),

          // Title
          TextField(
            controller: _titleCtrl,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Title (e.g. Order: Realme GT screen)',
              prefixIcon: const Icon(Icons.title_rounded, size: 18),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),

          // Body
          TextField(
            controller: _bodyCtrl,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  'Details (e.g. 2 pieces, red colour, from Rajan supplier...)',
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Icon(Icons.notes_rounded, size: 18),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 10),

          // Reminder row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    side: BorderSide(
                      color: _reminderDate != null
                          ? AppColors.warning
                          : theme.colorScheme.outlineVariant,
                    ),
                    foregroundColor: _reminderDate != null
                        ? AppColors.warning
                        : theme.colorScheme.onSurface,
                  ),
                  icon: Icon(
                    Icons.alarm_add_rounded,
                    size: 18,
                    color: _reminderDate != null
                        ? AppColors.warning
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  label: Text(
                    _reminderDate != null
                        ? 'Remind: ${Formatters.date(_reminderDate!)}'
                        : 'Set Reminder (optional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _reminderDate != null
                          ? FontWeight.bold
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
              if (_reminderDate != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: AppColors.debitRed),
                  tooltip: 'Remove reminder',
                  onPressed: () => setState(() => _reminderDate = null),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving || _titleCtrl.text.trim().isEmpty ? null : _save,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(
                isEdit ? 'Save Changes' : 'Save Note',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
