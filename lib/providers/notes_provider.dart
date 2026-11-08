import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/note_model.dart';
import '../providers/auth_provider.dart';
import '../providers/customer_provider.dart'; // re-exports firestoreServiceProvider
import '../services/firestore_service.dart';

// Stream of all notes (sorted: due reminders first, then by createdAt desc)
final notesStreamProvider = StreamProvider<List<NoteModel>>((ref) {
  final fs = ref.watch(firestoreServiceProvider);
  return fs.streamNotes();
});

// Count of due (overdue/today) reminders — used for badge on nav
final dueNotesCountProvider = Provider<int>((ref) {
  final notes = ref.watch(notesStreamProvider).valueOrNull ?? [];
  final now = DateTime.now();
  return notes.where((n) {
    if (n.reminderDate == null) return false;
    final d = n.reminderDate!;
    return d.year == now.year && d.month == now.month && d.day == now.day ||
        d.isBefore(now);
  }).length;
});

final notesNotifierProvider =
    AsyncNotifierProvider<NotesNotifier, void>(NotesNotifier.new);

class NotesNotifier extends AsyncNotifier<void> {
  FirestoreService get _fs => ref.read(firestoreServiceProvider);
  String get _uid =>
      ref.read(authStateProvider).valueOrNull?.uid ?? 'unknown';

  @override
  Future<void> build() async {}

  Future<void> addNote({
    required String title,
    required String body,
    DateTime? reminderDate,
  }) async {
    final note = NoteModel(
      id: const Uuid().v4(),
      title: title.trim(),
      body: body.trim(),
      reminderDate: reminderDate,
      createdAt: DateTime.now(),
      createdBy: _uid,
    );
    await _fs.addNote(note);
  }

  Future<void> updateNote(NoteModel note) async {
    await _fs.updateNote(note);
  }

  Future<void> deleteNote(String noteId) async {
    await _fs.deleteNote(noteId);
  }
}
