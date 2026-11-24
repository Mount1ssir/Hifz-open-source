import 'package:sqlite3/sqlite3.dart';

typedef Dhikr = ({String id, String text, String source, int target});
typedef Entry = ({
  String id,
  String text,
  String source,
  int target,
  int count,
  int revision,
  bool undo,
});

class AdhkarStore {
  AdhkarStore(this.db, {DateTime Function()? now}) : now = now ?? DateTime.now {
    final version = db.userVersion;
    if (version > 2) throw StateError('Unsupported adhkar database');
    if (version == 0) {
      transaction(() {
        db.execute(
          'CREATE TABLE personal(id INTEGER PRIMARY KEY, text TEXT NOT NULL, target INTEGER NOT NULL CHECK(target>0), archived INTEGER DEFAULT 0, round INTEGER DEFAULT 1)',
        );
        db.execute(
          'CREATE TABLE entries(session TEXT NOT NULL, position INTEGER NOT NULL, id TEXT NOT NULL, text TEXT NOT NULL, source TEXT NOT NULL, target INTEGER NOT NULL CHECK(target>0), count INTEGER DEFAULT 0, revision INTEGER DEFAULT 0, undo INTEGER DEFAULT 0, PRIMARY KEY(session,id))',
        );
        db.userVersion = 1;
      });
    }
    if (version < 2) {
      transaction(() {
        db.execute(
          'ALTER TABLE personal ADD COLUMN daily INTEGER NOT NULL DEFAULT 0',
        );
        db.userVersion = 2;
      });
    }
  }
  final Database db;
  final DateTime Function() now;
  String dailyKey(String group) =>
      '$group/${now().toLocal().toIso8601String().split('T').first}';

  T transaction<T>(T Function() action) {
    db.execute('BEGIN IMMEDIATE');
    try {
      final result = action();
      db.execute('COMMIT');
      return result;
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  void start(String session, List<Dhikr> items) => transaction(() {
    if (db.select('SELECT 1 FROM entries WHERE session=? LIMIT 1', [
      session,
    ]).isNotEmpty) {
      return;
    }
    for (final (i, d) in items.indexed) {
      db.execute(
        'INSERT INTO entries(session,position,id,text,source,target) VALUES(?,?,?,?,?,?)',
        [session, i, d.id, d.text, d.source, d.target],
      );
    }
  });

  List<Entry> entries(String session) => [
    for (final r in db.select(
      'SELECT * FROM entries WHERE session=? ORDER BY position',
      [session],
    ))
      (
        id: r['id'] as String,
        text: r['text'] as String,
        source: r['source'] as String,
        target: r['target'] as int,
        count: r['count'] as int,
        revision: r['revision'] as int,
        undo: r['undo'] == 1,
      ),
  ];

  // The expected revision identifies the tap. Replaying it after a commit
  // cannot apply it twice, even if the count later returns to the same value.
  void count(
    String session,
    Entry entry, {
    bool undo = false,
  }) => transaction(() {
    db.execute(
      'UPDATE entries SET count=count+?, revision=revision+1,undo=? WHERE session=? AND id=? AND revision=? AND ${undo ? 'undo=1 AND count>0' : 'count<target'}',
      [undo ? -1 : 1, undo ? 0 : 1, session, entry.id, entry.revision],
    );
    if (db.updatedRows == 1) {
      db.execute(
        'UPDATE entries SET undo=0 WHERE session=? AND id<>? AND undo=1',
        [session, entry.id],
      );
    }
  });

  List<({DateTime date, int count})> dailyHistory() {
    final today = now().toLocal();
    final dates = List.generate(
      7,
      (i) => DateTime(today.year, today.month, today.day - i),
    );
    String key(DateTime date) => date.toIso8601String().split('T').first;
    final rows = db.select(
      '''
      SELECT substr(session, -10) AS day, SUM(count) AS repetitions FROM entries
      WHERE (session LIKE 'morning/%' OR session LIKE 'evening/%' OR session LIKE 'personal/%/daily/%')
        AND substr(session, -10) BETWEEN ? AND ?
      GROUP BY day
    ''',
      [key(dates.last), key(dates.first)],
    );
    final counts = {
      for (final row in rows) row['day'] as String: row['repetitions'] as int,
    };
    return [
      for (final date in dates) (date: date, count: counts[key(date)] ?? 0),
    ];
  }

  List<Dhikr> personal() => [
    for (final r in db.select(
      'SELECT * FROM personal WHERE archived=0 ORDER BY id',
    ))
      (
        id: r['id'].toString(),
        text: r['text'] as String,
        target: r['target'] as int,
        source: 'شخصي',
      ),
  ];

  void save(String text, int target, {String? id, bool daily = false}) {
    if (text.trim().isEmpty || target < 1) throw ArgumentError();
    if (id == null) {
      db.execute('INSERT INTO personal(text,target,daily) VALUES(?,?,?)', [
        text.trim(),
        target,
        daily ? 1 : 0,
      ]);
    } else {
      db.execute(
        'UPDATE personal SET text=?,target=?,daily=? WHERE id=? AND archived=0',
        [text.trim(), target, daily ? 1 : 0, id],
      );
    }
  }

  void archive(String id) =>
      db.execute('UPDATE personal SET archived=1 WHERE id=?', [id]);
  Set<String> get recurringIds => {
    for (final r in db.select(
      'SELECT id FROM personal WHERE archived=0 AND daily=1',
    ))
      r['id'].toString(),
  };
  String personalKey(String id) {
    final r = db.select('SELECT daily,round FROM personal WHERE id=?', [
      id,
    ]).single;
    return r['daily'] == 1
        ? dailyKey('personal/$id/daily')
        : 'personal/$id/${r['round']}';
  }

  void nextRound(String id) =>
      db.execute('UPDATE personal SET round=round+1 WHERE id=?', [id]);
}
