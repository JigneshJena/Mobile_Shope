import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/note_model.dart';
import '../../providers/notes_provider.dart';
import '../../widgets/common/app_progress_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sticky Note Color Palette
// ─────────────────────────────────────────────────────────────────────────────
class NoteColors {
  static const List<Color> light = [
    Color(0xFFFEF9C3), // Soft Yellow
    Color(0xFFDCFCE7), // Soft Mint
    Color(0xFFE0F2FE), // Soft Sky Blue
    Color(0xFFFFEDD5), // Soft Peach
    Color(0xFFF3E8FF), // Soft Lavender
    Color(0xFFF1F5F9), // Soft Slate
  ];

  static const List<Color> dark = [
    Color(0xFF2E2611),
    Color(0xFF132E1D),
    Color(0xFF122B42),
    Color(0xFF361C12),
    Color(0xFF2B1838),
    Color(0xFF1E293B),
  ];

  static const List<Color> borders = [
    Color(0xFFEAB308),
    Color(0xFF22C55E),
    Color(0xFF38BDF8),
    Color(0xFFF97316),
    Color(0xFFA855F7),
    Color(0xFF94A3B8),
  ];

  static Color getBg(int index, bool isDark) {
    final i = (index >= 0 && index < light.length) ? index : 0;
    return isDark ? dark[i] : light[i];
  }

  static Color getBorder(int index) {
    final i = (index >= 0 && index < borders.length) ? index : 0;
    return borders[i];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notes Screen — Sticky Board View
// ─────────────────────────────────────────────────────────────────────────────
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  static void openEditor(BuildContext context, {NoteModel? note}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(initialNote: note),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(notesStreamProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order & Parts Notes'),
      ),
      body: notesAsync.when(
        data: (notes) {
          if (notes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.note_alt_outlined,
                        size: 32,
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
                      'Write future orders, items to purchase, or customer remarks like a quick sticky note.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => openEditor(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Write a Note'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Due notes first
          final due = notes.where((n) => n.isReminderDue).toList();
          final upcoming = notes.where((n) => n.isReminderUpcoming).toList();
          final plain = notes.where((n) => !n.hasReminder).toList();
          final sorted = [...due, ...upcoming, ...plain];

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.88,
            ),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final note = sorted[index];
              return StickyNoteCard(
                note: note,
                isDark: isDark,
                onTap: () => openEditor(context, note: note),
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
        error: (err, _) => Center(child: Text('Error loading notes: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'notes_add_fab',
        onPressed: () => openEditor(context),
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.onSecondary,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('New Note', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky Note Card (Authentic Post-it Note appearance)
// ─────────────────────────────────────────────────────────────────────────────
class StickyNoteCard extends StatelessWidget {
  const StickyNoteCard({
    super.key,
    required this.note,
    required this.isDark,
    required this.onTap,
  });

  final NoteModel note;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = NoteColors.getBg(note.colorIndex, isDark);
    final borderColor = note.isReminderDue
        ? AppColors.debitRed
        : NoteColors.getBorder(note.colorIndex).withValues(alpha: 0.4);

    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtleColor = isDark ? Colors.white70 : const Color(0xFF475569);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: note.isReminderDue ? 1.8 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Pin & Date
              Row(
                children: [
                  Icon(
                    note.isReminderDue
                        ? Icons.notifications_active_rounded
                        : note.hasReminder
                            ? Icons.alarm_rounded
                            : Icons.push_pin_rounded,
                    size: 14,
                    color: note.isReminderDue
                        ? AppColors.debitRed
                        : NoteColors.getBorder(note.colorIndex),
                  ),
                  const Spacer(),
                  Text(
                    Formatters.relative(note.createdAt),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: subtleColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Title
              if (note.title.isNotEmpty)
                Text(
                  note.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    height: 1.25,
                  ),
                ),
              if (note.title.isNotEmpty && note.body.isNotEmpty)
                const SizedBox(height: 4),

              // Body
              if (note.body.isNotEmpty)
                Expanded(
                  child: Text(
                    note.body,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: subtleColor,
                      height: 1.35,
                    ),
                  ),
                ),

              // Reminder badge at bottom
              if (note.hasReminder) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: note.isReminderDue
                        ? AppColors.debitRed.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.alarm_rounded,
                        size: 10,
                        color: note.isReminderDue ? AppColors.debitRed : textColor,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          Formatters.shortDate(note.reminderDate!),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: note.isReminderDue ? AppColors.debitRed : textColor,
                          ),
                          maxLines: 1,
                          overflow: TextPackage.ellipsis,
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

// Helper to avoid compile warning
typedef TextPackage = TextOverflow;

// ─────────────────────────────────────────────────────────────────────────────
// Note Editor Screen — Authentic Notepad Canvas (NO RIGID FORM)
// ─────────────────────────────────────────────────────────────────────────────
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({super.key, this.initialNote});

  final NoteModel? initialNote;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  DateTime? _reminderDate;
  int _colorIndex = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialNote?.title ?? '');
    _bodyCtrl = TextEditingController(text: widget.initialNote?.body ?? '');
    _reminderDate = widget.initialNote?.reminderDate;
    _colorIndex = widget.initialNote?.colorIndex ?? 0;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndClose() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    // If both empty, don't save empty note
    if (title.isEmpty && body.isEmpty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      if (widget.initialNote != null) {
        await ref.read(notesNotifierProvider.notifier).updateNote(
              widget.initialNote!.copyWith(
                title: title.isEmpty ? 'Untitled Note' : title,
                body: body,
                reminderDate: _reminderDate,
                colorIndex: _colorIndex,
              ),
            );
      } else {
        await ref.read(notesNotifierProvider.notifier).addNote(
              title: title.isEmpty ? 'Untitled Note' : title,
              body: body,
              reminderDate: _reminderDate,
              colorIndex: _colorIndex,
            );
      }
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _pickReminderDate() async {
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

  Future<void> _deleteNote() async {
    if (widget.initialNote == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Note?'),
        content: const Text('This note will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.debitRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(notesNotifierProvider.notifier).deleteNote(widget.initialNote!.id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = NoteColors.getBg(_colorIndex, isDark);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final hintColor = isDark ? Colors.white38 : const Color(0xFF94A3B8);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _saveAndClose();
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: textColor),
            onPressed: _saveAndClose,
            tooltip: 'Save & Back',
          ),
          actions: [
            // Reminder Button
            IconButton(
              icon: Icon(
                _reminderDate != null
                    ? Icons.alarm_on_rounded
                    : Icons.alarm_add_rounded,
                color: _reminderDate != null ? AppColors.secondary : textColor,
              ),
              tooltip: _reminderDate != null
                  ? 'Reminder: ${Formatters.date(_reminderDate!)}'
                  : 'Add Reminder',
              onPressed: _pickReminderDate,
            ),
            // Palette Picker
            PopupMenuButton<int>(
              icon: Icon(Icons.palette_outlined, color: textColor),
              tooltip: 'Note Color',
              onSelected: (val) => setState(() => _colorIndex = val),
              itemBuilder: (ctx) {
                return List.generate(NoteColors.light.length, (idx) {
                  return PopupMenuItem<int>(
                    value: idx,
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: NoteColors.light[idx],
                            shape: BoxShape.circle,
                            border: Border.all(color: NoteColors.borders[idx], width: 1.5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          ['Yellow', 'Mint', 'Sky Blue', 'Peach', 'Lavender', 'Slate'][idx],
                          style: TextStyle(
                            fontWeight: _colorIndex == idx ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (_colorIndex == idx) ...[
                          const Spacer(),
                          const Icon(Icons.check_rounded, size: 16),
                        ],
                      ],
                    ),
                  );
                });
              },
            ),
            // Delete (if editing)
            if (widget.initialNote != null)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.debitRed),
                tooltip: 'Delete Note',
                onPressed: _deleteNote,
              ),
            // Save Checkmark
            IconButton(
              icon: const Icon(Icons.check_rounded, color: AppColors.creditGreen, size: 22),
              tooltip: 'Done',
              onPressed: _saveAndClose,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Active Reminder banner
              if (_reminderDate != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.alarm_rounded, size: 15, color: AppColors.secondary),
                      const SizedBox(width: 6),
                      Text(
                        'Reminder: ${Formatters.date(_reminderDate!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () => setState(() => _reminderDate = null),
                        child: const Icon(Icons.close_rounded, size: 16, color: AppColors.debitRed),
                      ),
                    ],
                  ),
                ),

              // Notepad Canvas (No form inputs!)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      TextField(
                        controller: _titleCtrl,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          height: 1.3,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: 'Note Title...',
                          hintStyle: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: hintColor,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        Formatters.date(widget.initialNote?.createdAt ?? DateTime.now()),
                        style: TextStyle(
                          fontSize: 11,
                          color: hintColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Body canvas
                      TextField(
                        controller: _bodyCtrl,
                        style: TextStyle(
                          fontSize: 15,
                          color: textColor,
                          height: 1.5,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          hintText: 'Write note here... (parts to order, supplier phone, customer remarks...)',
                          hintStyle: TextStyle(fontSize: 15, color: hintColor),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          filled: false,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
