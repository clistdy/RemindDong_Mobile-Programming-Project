import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/user.dart';
import '../models/todo.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('reminddong.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';
    await db.execute('''
      CREATE TABLE users (
        id $idType,
        name $textType,
        email $textType UNIQUE,
        passwordHash $textType,
        createdAt $textType
      )
    ''');
    await db.execute('''
      CREATE TABLE todos (
        id $idType,
        title $textType,
        description TEXT,
        isCompleted $intType DEFAULT 0,
        priority $textType DEFAULT 'medium',
        createdAt $textType,
        dueDate TEXT,
        userId $intType,
        \`order\` $intType DEFAULT 0,
        FOREIGN KEY (userId) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE todos ADD COLUMN \`order\` INTEGER DEFAULT 0');
    }
  }

  Future<int> createUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserById(int id) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<int> createTodo(Todo todo) async {
    final db = await database;
    return await db.insert('todos', todo.toMap());
  }
  Future<List<Todo>> getTodosByUserId(int userId) async {
    final db = await database;
    final maps = await db.query(
      'todos',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: '`order` ASC, createdAt DESC',
    );

    return List.generate(maps.length, (i) => Todo.fromMap(maps[i]));
  }
  Future<List<Todo>> getCompletedTodos(int userId) async {
    final db = await database;
    final maps = await db.query(
      'todos',
      where: 'userId = ? AND isCompleted = 1',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );

    return List.generate(maps.length, (i) => Todo.fromMap(maps[i]));
  }
  Future<List<Todo>> getPendingTodos(int userId) async {
    final db = await database;
    final maps = await db.query(
      'todos',
      where: 'userId = ? AND isCompleted = 0',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    );

    return List.generate(maps.length, (i) => Todo.fromMap(maps[i]));
  }
  Future<int> updateTodo(Todo todo) async {
    final db = await database;
    return await db.update(
      'todos',
      todo.toMap(),
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }
  Future<int> deleteTodo(int id) async {
    final db = await database;
    return await db.delete(
      'todos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  Future<int> toggleTodoCompletion(int id, bool isCompleted) async {
    final db = await database;
    return await db.update(
      'todos',
      {'isCompleted': isCompleted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  Future<void> updateTaskOrder(List<Todo> todos) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < todos.length; i++) {
      batch.update(
        'todos',
        {'order': i},
        where: 'id = ?',
        whereArgs: [todos[i].id],
      );
    }
    await batch.commit(noResult: true);
  }
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'reminddong.db');
    await databaseFactory.deleteDatabase(path);
    _database = null;
  }
}
