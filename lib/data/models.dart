typedef Json = Map<String, dynamic>;

Json object(Object? value) => Map<String, dynamic>.from(value as Map);
int number(Object? value) => (value as num).toInt();

class Session {
  const Session(this.token, this.username, {this.needsBook = false});
  final String token;
  final String username;
  final bool needsBook;
  factory Session.fromJson(Json json) => Session(
    json['token'] as String,
    json['username'] as String,
    needsBook: json['needs_book'] == true,
  );
  Json toJson() => {
    'token': token,
    'username': username,
    'needs_book': needsBook,
  };
  Session confirmedBook() => Session(token, username);
}

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.description,
    required this.total,
    required this.learned,
    required this.mastered,
  });
  final String id, title, description;
  final int total, learned, mastered;
  factory Book.fromJson(Json json) => Book(
    id: json['book_id'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    total: number(json['total_words']),
    learned: number(json['learned_words']),
    mastered: number(json['mastered_words']),
  );
}

class BookCatalog {
  const BookCatalog(this.currentId, this.books);
  final String currentId;
  final List<Book> books;
  factory BookCatalog.fromJson(Json json) => BookCatalog(
    json['current_book_id'] as String,
    (json['books'] as List).map((b) => Book.fromJson(object(b))).toList(),
  );
}

class DailyTask {
  const DailyTask(
    this.target,
    this.finished,
    this.available,
    this.canStart,
    this.completed,
  );
  final int target, finished, available;
  final bool canStart, completed;
  double get progress => target > 0 ? (finished / target).clamp(0.0, 1.0) : 0;
  int get remaining => (target - finished).clamp(0, target);
  factory DailyTask.fromJson(Json json, {required bool review}) => DailyTask(
    number(json['target_count']),
    number(json[review ? 'reviewed_today' : 'learned_today']),
    number(json[review ? 'due_count' : 'available_count']),
    json['can_start'] == true,
    json['is_completed'] == true,
  );
}

class LastStory {
  const LastStory(this.id, this.title, this.progress, this.words);
  final int id, words;
  final String title;
  final double progress;
  factory LastStory.fromJson(Json json) => LastStory(
    number(json['story_id']),
    json['title'] as String,
    (json['progress'] as num).toDouble(),
    number(json['embedded_word_count']),
  );
}

class Dashboard {
  const Dashboard(
    this.bookId,
    this.bookTitle,
    this.learn,
    this.review,
    this.lastStory,
  );
  final String bookId, bookTitle;
  final DailyTask learn, review;
  final LastStory? lastStory;
  factory Dashboard.fromJson(Json json) => Dashboard(
    object(json['current_book'])['book_id'] as String,
    object(json['current_book'])['title'] as String,
    DailyTask.fromJson(object(json['new_task']), review: false),
    DailyTask.fromJson(object(json['review_task']), review: true),
    json['last_story'] == null
        ? null
        : LastStory.fromJson(object(json['last_story'])),
  );
}

class UserStats {
  const UserStats(this.days, this.learned, this.mastered, this.read);
  final int days, learned, mastered, read;
  factory UserStats.fromJson(Json json) => UserStats(
    number(json['total_study_days']),
    number(json['total_learned_words']),
    number(json['total_mastered_words']),
    number(json['total_read_stories']),
  );
}

class HomeData {
  const HomeData(this.dashboard, this.stats, this.catalog);
  final Dashboard dashboard;
  final UserStats stats;
  final BookCatalog catalog;
  Book? get currentBook {
    for (final book in catalog.books) {
      if (book.id == dashboard.bookId) return book;
    }
    return null;
  }
}
