import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class DbService {
  DbService._();

  static final DbService instance = DbService._();

  Database? _database;

  Database get database {
    final db = _database;
    if (db == null) throw StateError('Database not initialized. Call init() first.');
    return db;
  }

  Future<void> init() async {
    if (_database != null) return;

    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'restaurant.db');

    _database = await openDatabase(
      path,
      version: 7,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createCoreTables(db);
    await _createNewTables(db);
    await _createV3Tables(db);
    await _createIndexes(db);
    await _seedAll(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createNewTables(db);
      await _alterOrdersTable(db);
    }
    if (oldVersion < 3) {
      await _createV3Tables(db);
    }
    if (oldVersion < 5) {
      final dishColumns = await db.rawQuery("PRAGMA table_info(dishes)");
      final dishColNames = dishColumns.map((c) => c['name'].toString()).toSet();
      if (!dishColNames.contains('cost_price')) {
        await db.execute("ALTER TABLE dishes ADD COLUMN cost_price REAL NOT NULL DEFAULT 0");
      }
      if (!dishColNames.contains('volume')) {
        await db.execute("ALTER TABLE dishes ADD COLUMN volume TEXT");
      }
      if (!dishColNames.contains('unit')) {
        await db.execute("ALTER TABLE dishes ADD COLUMN unit TEXT DEFAULT 'шт'");
      }
    }
    if (oldVersion < 6) {
      await _seedExtraCustomers(db);
      await _seedCashRegisters(db);
    }
    if (oldVersion < 7) {
      // Re-seed cash registers with correct column names
      await db.delete('cash_registers');
      await _seedCashRegisters(db);
      // Add seed data for reservations and shifts
      await _seedReservations(db);
      await _seedShifts(db);
    }
    await _createIndexes(db);
  }

  Future<void> _seedExtraCustomers(Database db) async {
    final moreCustomers = [
      ['Андрей Кузнецов', '+7-903-100-2001', 'andrey.k@mail.ru', 'Предпочитает летнюю веранду', null, 22, 68000.00, '2026-06-14'],
      ['Наталья Федорова', '+7-903-100-2002', 'natalya.f@mail.ru', 'Вегетарианское меню', 'Глютен', 14, 42000.00, '2026-06-13'],
      ['Виктор Лебедев', '+7-903-100-2003', null, 'Часто заказывает десерты', null, 31, 87000.00, '2026-06-15'],
      ['Елена Семёнова', '+7-903-100-2004', 'elena.s@mail.ru', 'Детское меню', 'Орехи', 7, 21000.00, '2026-06-11'],
      ['Артём Попов', '+7-903-100-2005', 'artem.p@mail.ru', 'Бизнес ланчи', null, 35, 92000.00, '2026-06-15'],
      ['Оксана Новикова', '+7-903-100-2006', 'oksana.n@mail.ru', 'VIP гость', null, 19, 110000.00, '2026-06-14'],
      ['Роман Волков', '+7-903-100-2007', 'roman.v@mail.ru', 'Спортивные обеды', null, 11, 35000.00, '2026-06-12'],
      ['Татьяна Морозова', '+7-903-100-2008', null, 'Праздничные ужины', 'Молочные', 25, 78000.00, '2026-06-15'],
      ['Игорь Петров', '+7-903-100-2009', 'igor.p@mail.ru', 'Командные обеды', null, 16, 53000.00, '2026-06-10'],
      ['Юлия Соколова', '+7-903-100-2010', 'yulia.s@mail.ru', 'Дегустации вин', null, 9, 29000.00, '2026-06-13'],
      ['Максим Орлов', '+7-903-100-2011', 'maxim.o@mail.ru', 'Частый гость по вечерам', null, 27, 81000.00, '2026-06-15'],
      ['Светлана Козлова', '+7-903-100-2012', 'svetlana.k@mail.ru', 'Бранчи по воскресеньям', 'Лактоза', 13, 40000.00, '2026-06-14'],
      ['Денис Новиков', '+7-903-100-2013', null, 'Корпоративные заказы', null, 38, 145000.00, '2026-06-15'],
      ['Анастасия Иванова', '+7-903-100-2014', 'anastasia.i@mail.ru', 'Романтические ужины', null, 6, 19000.00, '2026-06-12'],
      ['Пётр Козлов', '+7-903-100-2015', 'petr.k@mail.ru', 'Знаток мясных блюд', null, 20, 64000.00, '2026-06-14'],
      ['Валентина Белова', '+7-903-100-2016', 'valentina.b@mail.ru', 'Диетическое питание', 'Глютен', 4, 12000.00, '2026-06-10'],
      ['Кирилл Зайцев', '+7-903-100-2017', 'kirill.z@mail.ru', 'Спортивное питание', null, 17, 51000.00, '2026-06-13'],
      ['Галина Павлова', '+7-903-100-2018', 'galina.p@mail.ru', 'Семейные обеды', null, 23, 69000.00, '2026-06-15'],
      ['Степан Романов', '+7-903-100-2019', null, 'Фуд-блогер', null, 10, 31000.00, '2026-06-14'],
      ['Лидия Егорова', '+7-903-100-2020', 'lidia.e@mail.ru', 'Деловые встречи', null, 29, 93000.00, '2026-06-15'],
      ['Фёдор Жуков', '+7-903-100-2021', 'fedor.j@mail.ru', 'Любитель морепродуктов', 'Молочные', 12, 38000.00, '2026-06-11'],
      ['Варвара Тимофеева', '+7-903-100-2022', 'varvara.t@mail.ru', 'Винные вечера', null, 8, 25000.00, '2026-06-13'],
      ['Глеб Сидоров', '+7-903-100-2023', null, 'Командировки', null, 21, 63000.00, '2026-06-14'],
      ['Ксения Филиппова', '+7-903-100-2024', 'ksenia.f@mail.ru', 'Студенческие скидки', null, 15, 28000.00, '2026-06-12'],
      ['Александр Давыдов', '+7-903-100-2025', 'alexandr.d@mail.ru', 'Юбилейные банкеты', null, 33, 155000.00, '2026-06-15'],
    ];

    final existing = await db.rawQuery('SELECT COUNT(*) as cnt FROM customers');
    final cnt = (existing.first['cnt'] as int?) ?? 0;
    if (cnt <= 8) {
      for (final c in moreCustomers) {
        await db.rawInsert(
          'INSERT INTO customers (name, phone, email, notes, allergies, visit_count, total_spent, last_visit) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          c,
        );
      }
    }
  }

  Future<void> _seedCashRegisters(Database db) async {
    final existing = await db.rawQuery('SELECT COUNT(*) as cnt FROM cash_registers');
    final cnt = (existing.first['cnt'] as int?) ?? 0;
    if (cnt > 0) return;

    final now = DateTime.now();
    for (int d = 0; d < 30; d++) {
      final date = now.subtract(Duration(days: d));
      final openDate = DateTime(date.year, date.month, date.day, 9, 0);
      final closeDate = DateTime(date.year, date.month, date.day, 23, 0);
      final cash = 8000.0 + (d % 5) * 2000.0;
      final card = 12000.0 + (d % 3) * 3000.0;
      final other = 1000.0 + (d % 4) * 500.0;
      final total = cash + card + other;
      final ordersCount = 20 + (d % 10);
      await db.insert('cash_registers', {
        'open_time': openDate.toIso8601String(),
        'close_time': closeDate.toIso8601String(),
        'opening_balance': 15000.0,
        'expected_balance': 15000.0 + total,
        'closing_balance': 15000.0 + total + 100.0,
        'discrepancy': 100.0,
        'total_cash': cash,
        'total_card': card,
        'total_other': other,
        'total_orders': ordersCount,
        'status': 'Закрыта',
      });
    }
  }

  Future<void> _createCoreTables(Database db) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE dishes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER,
        name TEXT NOT NULL,
        price REAL NOT NULL CHECK (price >= 0),
        cost_price REAL NOT NULL DEFAULT 0 CHECK (cost_price >= 0),
        description TEXT,
        volume TEXT,
        unit TEXT DEFAULT 'шт',
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_number TEXT NOT NULL UNIQUE,
        order_date TEXT NOT NULL DEFAULT (datetime('now')),
        total_amount REAL NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
        payment_method TEXT,
        notes TEXT,
        waiter_id INTEGER,
        table_id INTEGER,
        discount_id INTEGER,
        discount_amount REAL NOT NULL DEFAULT 0 CHECK (discount_amount >= 0),
        status TEXT NOT NULL DEFAULT 'Новый'
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        dish_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL CHECK (quantity > 0),
        unit_price REAL NOT NULL CHECK (unit_price >= 0),
        line_total REAL NOT NULL DEFAULT 0 CHECK (line_total >= 0),
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
        FOREIGN KEY (dish_id) REFERENCES dishes(id)
      )
    ''');
  }

  Future<void> _createNewTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS waiters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        role TEXT NOT NULL DEFAULT 'Официант',
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        base_salary REAL NOT NULL DEFAULT 0,
        hire_date TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS restaurant_tables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_number INTEGER NOT NULL UNIQUE,
        capacity INTEGER NOT NULL DEFAULT 2,
        zone TEXT NOT NULL DEFAULT 'Основной зал',
        status TEXT NOT NULL DEFAULT 'Свободен',
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS reservations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_id INTEGER,
        customer_name TEXT NOT NULL,
        phone TEXT,
        reservation_date TEXT NOT NULL,
        party_size INTEGER NOT NULL DEFAULT 1,
        status TEXT NOT NULL DEFAULT 'Подтверждено',
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (table_id) REFERENCES restaurant_tables(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS tips (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER,
        waiter_id INTEGER,
        amount REAL NOT NULL CHECK (amount >= 0),
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE SET NULL,
        FOREIGN KEY (waiter_id) REFERENCES waiters(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        waiter_id INTEGER,
        start_time TEXT NOT NULL,
        end_time TEXT,
        status TEXT NOT NULL DEFAULT 'Активна',
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (waiter_id) REFERENCES waiters(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        amount REAL NOT NULL CHECK (amount >= 0),
        expense_date TEXT NOT NULL,
        receipt_number TEXT,
        supplier TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS discounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        description TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'percent',
        value REAL NOT NULL CHECK (value >= 0),
        min_order_amount REAL,
        max_discount_amount REAL,
        valid_from TEXT NOT NULL,
        valid_to TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        usage_limit INTEGER,
        usage_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  Future<void> _createV3Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        notes TEXT,
        allergies TEXT,
        visit_count INTEGER NOT NULL DEFAULT 0,
        total_spent REAL NOT NULL DEFAULT 0,
        last_visit TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_registers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        shift_id INTEGER,
        open_time TEXT NOT NULL,
        close_time TEXT,
        opening_balance REAL NOT NULL DEFAULT 0,
        closing_balance REAL NOT NULL DEFAULT 0,
        expected_balance REAL NOT NULL DEFAULT 0,
        discrepancy REAL NOT NULL DEFAULT 0,
        total_cash REAL NOT NULL DEFAULT 0,
        total_card REAL NOT NULL DEFAULT 0,
        total_other REAL NOT NULL DEFAULT 0,
        total_orders INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'Открыта',
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (shift_id) REFERENCES shifts(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        unit TEXT DEFAULT 'кг',
        current_stock REAL NOT NULL DEFAULT 0,
        min_stock REAL NOT NULL DEFAULT 0,
        max_stock REAL NOT NULL DEFAULT 100,
        cost_per_unit REAL NOT NULL DEFAULT 0,
        supplier TEXT,
        last_restocked TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS waiter_schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        waiter_id INTEGER,
        date TEXT NOT NULL,
        start_time TEXT NOT NULL DEFAULT '09:00',
        end_time TEXT NOT NULL DEFAULT '18:00',
        status TEXT NOT NULL DEFAULT 'Запланирована',
        notes TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (waiter_id) REFERENCES waiters(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS split_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER,
        payment_method TEXT NOT NULL,
        amount REAL NOT NULL CHECK (amount >= 0),
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('ALTER TABLE orders ADD COLUMN customer_id INTEGER');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_inventory_category ON inventory(category)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_waiter_schedules_date ON waiter_schedules(date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_split_payments_order_id ON split_payments(order_id)');
  }

  Future<void> _alterOrdersTable(Database db) async {
    final columns = await db.rawQuery("PRAGMA table_info(orders)");
    final colNames = columns.map((c) => c['name'].toString()).toSet();

    if (!colNames.contains('waiter_id')) {
      await db.execute('ALTER TABLE orders ADD COLUMN waiter_id INTEGER');
    }
    if (!colNames.contains('table_id')) {
      await db.execute('ALTER TABLE orders ADD COLUMN table_id INTEGER');
    }
    if (!colNames.contains('discount_id')) {
      await db.execute('ALTER TABLE orders ADD COLUMN discount_id INTEGER');
    }
    if (!colNames.contains('discount_amount')) {
      await db.execute("ALTER TABLE orders ADD COLUMN discount_amount REAL NOT NULL DEFAULT 0");
    }
    if (!colNames.contains('status')) {
      await db.execute("ALTER TABLE orders ADD COLUMN status TEXT NOT NULL DEFAULT 'Новый'");
    }

    final dishColumns = await db.rawQuery("PRAGMA table_info(dishes)");
    final dishColNames = dishColumns.map((c) => c['name'].toString()).toSet();
    if (!dishColNames.contains('cost_price')) {
      await db.execute("ALTER TABLE dishes ADD COLUMN cost_price REAL NOT NULL DEFAULT 0");
    }
  }

  Future<void> _createIndexes(Database db) async {
    final indexes = [
      'CREATE INDEX IF NOT EXISTS idx_dishes_category_id ON dishes(category_id)',
      'CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id)',
      'CREATE INDEX IF NOT EXISTS idx_order_items_dish_id ON order_items(dish_id)',
      'CREATE INDEX IF NOT EXISTS idx_orders_order_date ON orders(order_date)',
      'CREATE INDEX IF NOT EXISTS idx_orders_waiter_id ON orders(waiter_id)',
      'CREATE INDEX IF NOT EXISTS idx_orders_table_id ON orders(table_id)',
      'CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status)',
      'CREATE INDEX IF NOT EXISTS idx_tips_waiter_id ON tips(waiter_id)',
      'CREATE INDEX IF NOT EXISTS idx_tips_order_id ON tips(order_id)',
      'CREATE INDEX IF NOT EXISTS idx_shifts_waiter_id ON shifts(waiter_id)',
      'CREATE INDEX IF NOT EXISTS idx_reservations_table_id ON reservations(table_id)',
      'CREATE INDEX IF NOT EXISTS idx_reservations_date ON reservations(reservation_date)',
      'CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(expense_date)',
    ];
    for (final idx in indexes) {
      await db.execute(idx);
    }
  }

  Future<void> _seedAll(Database db) async {
    final categories = [
      [1, 'Закуски', 'Антипасто и легкие блюда для начала трапезы'],
      [2, 'Супы', 'Традиционные супы европейской кухни'],
      [3, 'Основные блюда', 'Мясо, птица и рыба на гриле'],
      [4, 'Паста и ризотто', 'Классические итальянские блюда'],
      [5, 'Гарниры', 'Овощи и крупы к основным блюдам'],
      [6, 'Салаты', 'Свежие салаты из сезонных овощей'],
      [7, 'Десерты', 'Авторские сладкие блюда'],
      [8, 'Напитки', 'Кофе, чай и прохладительные напитки'],
    ];

    for (final c in categories) {
      await db.rawInsert(
        'INSERT INTO categories (id, name, description) VALUES (?, ?, ?)',
        c,
      );
    }

    final dishes = [
      // Закуски (6)
      [1, 1, 'Брускетта с томатами', 380.00, 95.00, 'Тосты с помидорами, базиликом и оливковым маслом', '4 шт', 'шт'],
      [2, 1, 'Карпаччо из говядины', 620.00, 210.00, 'Тонко нарезанная говядина с пармезаном и рукколой', '150 г', 'г'],
      [3, 1, 'Сырная тарелка', 750.00, 280.00, 'Ассорти из 5 сортов сыра с мёдом и орехами', '200 г', 'г'],
      [4, 1, 'Креветки на гриле', 680.00, 240.00, 'Королевские креветки с чесноком и лимоном', '250 г', 'г'],
      [5, 1, 'Тартар из лосося', 650.00, 250.00, 'Свежий лосось с авокадо и каперсами', '150 г', 'г'],
      [6, 1, 'Мидии в белом вине', 580.00, 200.00, 'Мидии с чесноком, петрушкой и сухим вином', '300 г', 'г'],

      // Супы (4)
      [7, 2, 'Томатный суп с базиликом', 420.00, 85.00, 'Густой суп из спелых томатов', '350 мл', 'мл'],
      [8, 2, 'Борщ классический', 450.00, 110.00, 'Наваристый борщ с говядиной и сметаной', '400 мл', 'мл'],
      [9, 2, 'Грибной крем-суп', 430.00, 90.00, 'Суп из белых грибов со сливками', '350 мл', 'мл'],
      [10, 2, 'Французский луковый', 460.00, 95.00, 'Карамелизованный лук с гренками и сыром', '350 мл', 'мл'],

      // Основные блюда (8)
      [11, 3, 'Стейк Рибай', 1950.00, 750.00, 'Мраморная говядина на гриле с розмарином', '300 г', 'г'],
      [12, 3, 'Лосось на гриле', 1400.00, 520.00, 'Филе лосося с лимоном и зеленью', '250 г', 'г'],
      [13, 3, 'Утка с апельсином', 1500.00, 480.00, 'Запечённая утиная грудка с апельсиновой глазурью', '250 г', 'г'],
      [14, 3, 'Телятина по-флорентийски', 1700.00, 620.00, 'Телячья отбивная с артишоками и сыром', '280 г', 'г'],
      [15, 3, 'Свиная рулька', 1200.00, 350.00, 'Запечённая голяшка с пивным соусом', '400 г', 'г'],
      [16, 3, 'Рататуй', 650.00, 130.00, 'Запечённые овощи с прованскими травами', '300 г', 'г'],
      [17, 3, 'Курица в сливочном соусе', 890.00, 220.00, 'Филе курицы со сливками и грибами', '250 г', 'г'],
      [18, 3, 'Морской окунь на гриле', 1350.00, 450.00, 'Филе окуня с лимонным маслом', '250 г', 'г'],

      // Паста и ризотто (4)
      [19, 4, 'Паста Карбонара', 820.00, 180.00, 'Спагетти с беконом, яйцом и пармезаном', '300 г', 'г'],
      [20, 4, 'Ризотто с грибами', 850.00, 200.00, 'Рис арборио с белыми грибами', '280 г', 'г'],
      [21, 4, 'Лазанья', 880.00, 200.00, 'Слоёное блюдо с мясом и бешамелем', '300 г', 'г'],
      [22, 4, 'Паста Болоньезе', 720.00, 160.00, 'Спагетти с мясным соусом', '300 г', 'г'],

      // Гарниры (4)
      [23, 5, 'Картофель фри', 320.00, 55.00, 'Хрустящий картофель с розмарином', '150 г', 'г'],
      [24, 5, 'Картофельное пюре', 280.00, 50.00, 'Нежное пюре со сливочным маслом', '150 г', 'г'],
      [25, 5, 'Овощи гриль', 360.00, 75.00, 'Цукини, перец и баклажаны на гриле', '200 г', 'г'],
      [26, 5, 'Спаржа с голландезом', 520.00, 160.00, 'Зелёная спаржа с масляным соусом', '150 г', 'г'],

      // Салаты (4)
      [27, 6, 'Цезарь с курицей', 680.00, 180.00, 'Классический салат с пармезаном', '250 г', 'г'],
      [28, 6, 'Греческий салат', 550.00, 120.00, 'Томаты, огурцы, фета и маслины', '250 г', 'г'],
      [29, 6, 'Нисуаз', 720.00, 210.00, 'Салат с тунцом, яйцами и фасолью', '280 г', 'г'],
      [30, 6, 'Салат с креветками', 750.00, 260.00, 'Креветки, авокадо и руккола', '250 г', 'г'],

      // Десерты (5)
      [31, 7, 'Тирамису', 520.00, 120.00, 'Классический десерт с маскарпоне', '180 г', 'г'],
      [32, 7, 'Крем-брюле', 490.00, 95.00, 'Заварной крем с карамельной корочкой', '150 г', 'г'],
      [33, 7, 'Шоколадный фондан', 560.00, 110.00, 'Пирожное с жидкой шоколадной начинкой', '150 г', 'г'],
      [34, 7, 'Яблочный штрудель', 480.00, 85.00, 'Слоёный рулет с яблоками и корицей', '180 г', 'г'],
      [35, 7, 'Панна-котта', 460.00, 80.00, 'Ванильный десерт с ягодным соусом', '150 г', 'г'],

      // Напитки (6)
      [36, 8, 'Капучино', 280.00, 45.00, 'Кофе с молочной пеной', '300 мл', 'мл'],
      [37, 8, 'Латте', 300.00, 50.00, 'Кофе с молоком', '350 мл', 'мл'],
      [38, 8, 'Эспрессо', 220.00, 30.00, 'Крепкий чёрный кофе', '60 мл', 'мл'],
      [39, 8, 'Зелёный чай', 220.00, 25.00, 'Китайский зелёный чай', 'Чайник 400 мл', 'мл'],
      [40, 8, 'Лимонад домашний', 350.00, 60.00, 'Лимонад с мятой и лаймом', '400 мл', 'мл'],
      [41, 8, 'Сок апельсиновый', 280.00, 55.00, 'Свежевыжатый апельсиновый сок', '300 мл', 'мл'],
    ];

    for (final d in dishes) {
      await db.rawInsert(
        'INSERT INTO dishes (id, category_id, name, price, cost_price, description, volume, unit) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        d,
      );
    }

    await _seedWaiters(db);
    await _seedTables(db);
    await _seedDiscounts(db);
    await _seedPrimaryCustomers(db);
    await _seedExtraCustomers(db);
    await _seedOrdersWithWaiters(db);
    await _recalculateCustomerStats(db);
    await _seedExpenses(db);
    await _seedTips(db);
    await _seedInventory(db);
    await _seedSchedules(db);
    await _seedReservations(db);
    await _seedShifts(db);
  }

  Future<void> _seedWaiters(Database db) async {
    final waiters = [
      [1, 'Александр Петров', '+7-916-123-4567', 'alex@cibus.ru', 'Старший официант', 1, 45000, '2024-03-15'],
      [2, 'Мария Иванова', '+7-916-234-5678', 'maria@cibus.ru', 'Официант', 1, 38000, '2024-06-01'],
      [3, 'Дмитрий Сидоров', '+7-916-345-6789', 'dmitry@cibus.ru', 'Официант', 1, 38000, '2025-01-10'],
      [4, 'Елена Козлова', '+7-916-456-7890', 'elena@cibus.ru', 'Бармен', 1, 40000, '2025-03-20'],
      [5, 'Андрей Новиков', '+7-916-567-8901', 'andrey@cibus.ru', 'Официант', 1, 38000, '2025-08-01'],
      [6, 'Ольга Морозова', '+7-916-678-9012', 'olga@cibus.ru', 'Официант', 1, 36000, '2025-09-15'],
      [7, 'Сергей Волков', '+7-916-789-0123', 'sergey@cibus.ru', 'Официант', 1, 36000, '2025-10-01'],
      [8, 'Анна Лебедева', '+7-916-890-1234', 'anna@cibus.ru', 'Официант', 1, 36000, '2025-11-20'],
      [9, 'Павел Соколов', '+7-916-901-2345', 'pavel@cibus.ru', 'Официант', 1, 36000, '2026-01-05'],
      [10, 'Наталья Попова', '+7-916-012-3456', 'natalya@cibus.ru', 'Официант', 1, 36000, '2026-02-01'],
    ];

    for (final w in waiters) {
      await db.rawInsert(
        'INSERT INTO waiters (id, name, phone, email, role, is_active, base_salary, hire_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        w,
      );
    }
  }

  Future<void> _seedTables(Database db) async {
    final tables = [
      [1, 1, 2, 'Основной зал', 'Свободен'],
      [2, 2, 2, 'Основной зал', 'Свободен'],
      [3, 3, 4, 'Основной зал', 'Занят'],
      [4, 4, 4, 'Основной зал', 'Свободен'],
      [5, 5, 6, 'Основной зал', 'Свободен'],
      [6, 6, 8, 'Основной зал', 'Забронирован'],
      [7, 7, 2, 'Терраса', 'Свободен'],
      [8, 8, 4, 'Терраса', 'Свободен'],
      [9, 9, 6, 'Терраса', 'Свободен'],
      [10, 10, 10, 'Банкетный зал', 'Свободен'],
      [11, 11, 12, 'Банкетный зал', 'Свободен'],
      [12, 12, 4, 'VIP зона', 'Свободен'],
      [13, 13, 6, 'VIP зона', 'Занят'],
      [14, 14, 2, 'У бара', 'Свободен'],
      [15, 15, 2, 'У бара', 'Свободен'],
    ];

    for (final t in tables) {
      await db.rawInsert(
        'INSERT INTO restaurant_tables (id, table_number, capacity, zone, status) VALUES (?, ?, ?, ?, ?)',
        t,
      );
    }
  }

  Future<void> _seedDiscounts(Database db) async {
    final discounts = [
      [1, 'VIP10', 'Скидка VIP 10%', 'percent', 10.0, null, null, '2026-01-01', '2026-12-31', 1, null, 15],
      [2, 'NEWYEAR', 'Новогодняя скидка 15%', 'percent', 15.0, 2000.0, 500.0, '2026-12-01', '2027-01-15', 1, 100, 3],
      [3, 'BIRTHDAY', 'Именинник -500₽', 'fixed', 500.0, 1500.0, null, '2026-01-01', '2026-12-31', 1, null, 8],
      [4, 'EARLY5', 'Ранняя пташка -5%', 'percent', 5.0, null, null, '2026-01-01', '2026-12-31', 1, null, 22],
    ];

    for (final d in discounts) {
      await db.rawInsert(
        'INSERT INTO discounts (id, code, description, type, value, min_order_amount, max_discount_amount, valid_from, valid_to, is_active, usage_limit, usage_count) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        d,
      );
    }
  }

  Future<void> _seedOrdersWithWaiters(Database db) async {
    final paymentMethods = ['Наличные', 'Карта', 'Безнал', 'Наличные', 'Карта', 'Карта', 'Наличные', 'Карта'];

    // Realistic status distribution: kitchen has orders, most are paid
    final statuses = ['Оплачен', 'Оплачен', 'Оплачен', 'Оплачен', 'Подан', 'Готово', 'Новый', 'Готовится'];

    // Uneven waiter distribution: senior gets more, new hires get fewer
    final waiterWeights = [16, 13, 12, 11, 10, 9, 9, 8, 7, 5]; // total = 100, repeated 10x = 1000
    final waiterPool = <int>[];
    for (int i = 0; i < 1000; i++) {
      int r = i % 100;
      int waiter = 0;
      for (int cum = 0; waiter < waiterWeights.length; waiter++) {
        cum += waiterWeights[waiter];
        if (r < cum) break;
      }
      waiterPool.add(waiter + 1);
    }

    final random = DateTime(2026, 1, 1);

    for (int i = 1; i <= 1000; i++) {
      final dayOffset = (i * 180 ~/ 1000);
      final date = random.add(Duration(days: dayOffset));
      final hour = 11 + (i % 12);
      final minute = (i * 7) % 60;
      final orderDate = DateTime(date.year, date.month, date.day, hour, minute);

      final orderNumber = 'ORD-${i.toString().padLeft(5, '0')}';
      final waiterId = waiterPool[i - 1];
      final tableId = 1 + (i % 15);
      final paymentMethod = paymentMethods[i % paymentMethods.length];
      final status = statuses[i % statuses.length];

      // Link 300 orders (30%) to customers 1-33
      final customerId = (i % 10 == 0 || i % 7 == 0 || i % 13 == 0) ? 1 + (i % 33) : null;

      final itemCount = 1 + (i % 4);
      double totalAmount = 0;

      await db.rawInsert(
        'INSERT INTO orders (order_number, order_date, total_amount, payment_method, waiter_id, table_id, status, customer_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        [orderNumber, orderDate.toIso8601String(), 0, paymentMethod, waiterId, tableId, status, customerId],
      );

      final orderId = await db.rawQuery('SELECT last_insert_rowid() as id');
      final oid = (orderId.first['id'] as int);

      for (int j = 0; j < itemCount; j++) {
        final dishId = 1 + ((i + j * 13) % 41);
        final qty = 1 + ((i + j) % 3);
        final priceResult = await db.rawQuery('SELECT price FROM dishes WHERE id = ?', [dishId]);
        final price = (priceResult.isNotEmpty ? (priceResult.first['price'] as double) : 500.0);
        final lineTotal = price * qty;
        totalAmount += lineTotal;

        await db.rawInsert(
          'INSERT INTO order_items (order_id, dish_id, quantity, unit_price, line_total) VALUES (?, ?, ?, ?, ?)',
          [oid, dishId, qty, price, lineTotal],
        );
      }

      if (i % 5 == 0) {
        final discountId = 1 + (i % 4);
        final discountAmount = totalAmount * 0.1;
        totalAmount -= discountAmount;
        await db.rawUpdate(
          'UPDATE orders SET total_amount = ?, discount_id = ?, discount_amount = ? WHERE id = ?',
          [totalAmount, discountId, discountAmount, oid],
        );
      } else {
        await db.rawUpdate(
          'UPDATE orders SET total_amount = ? WHERE id = ?',
          [totalAmount, oid],
        );
      }
    }
  }

  Future<void> _seedExpenses(Database db) async {
    final expenses = [
      ['Продукты', 'Закупка овощей и зелени (январь)', 12500.00, '2026-01-10', 'РК-001', 'ОвощеПром'],
      ['Продукты', 'Мясо и птица (январь)', 45000.00, '2026-01-15', 'РК-002', 'МясоПром'],
      ['Продукты', 'Рыба и морепродукты (январь)', 32000.00, '2026-01-20', 'РК-003', 'РыбаТорг'],
      ['Продукты', 'Молочные продукты', 8500.00, '2026-01-22', 'РК-004', 'МолочныйДом'],
      ['Продукты', 'Бакалея и специи', 6200.00, '2026-01-25', 'РК-005', 'СпецииМира'],
      ['Зарплата', 'Зарплата официантам (январь)', 199000.00, '2026-01-31', null, null],
      ['Зарплата', 'Зарплата поварам (январь)', 280000.00, '2026-01-31', null, null],
      ['Коммунальные', 'Аренда помещения', 180000.00, '2026-01-05', null, null],
      ['Коммунальные', 'Электричество и газ', 28000.00, '2026-01-05', null, null],
      ['Коммунальные', 'Вода и канализация', 12000.00, '2026-01-05', null, null],

      ['Продукты', 'Закупка овощей (февраль)', 13000.00, '2026-02-08', 'РК-010', 'ОвощеПром'],
      ['Продукты', 'Мясо и птица (февраль)', 47000.00, '2026-02-12', 'РК-011', 'МясоПром'],
      ['Продукты', 'Вина и напитки', 65000.00, '2026-02-15', 'РК-012', 'ВиноТорг'],
      ['Зарплата', 'Зарплата (февраль)', 479000.00, '2026-02-28', null, null],
      ['Коммунальные', 'Аренда (февраль)', 180000.00, '2026-02-05', null, null],

      ['Продукты', 'Закупка овощей (март)', 14000.00, '2026-03-10', 'РК-020', 'ОвощеПром'],
      ['Продукты', 'Мясо и птица (март)', 50000.00, '2026-03-14', 'РК-021', 'МясоПром'],
      ['Продукты', 'Рыба и морепродукты (март)', 35000.00, '2026-03-18', 'РК-022', 'РыбаТорг'],
      ['Оборудование', 'Ремонт посудомоечной машины', 15000.00, '2026-03-20', 'РМ-001', 'РесторанСервис'],
      ['Маркетинг', 'Реклама в соцсетях', 25000.00, '2026-03-25', null, null],
      ['Зарплата', 'Зарплата (март)', 479000.00, '2026-03-31', null, null],

      ['Продукты', 'Закупка овощей (апрель)', 13500.00, '2026-04-08', 'РК-030', 'ОвощеПром'],
      ['Продукты', 'Мясо и птица (апрель)', 48000.00, '2026-04-12', 'РК-031', 'МясоПром'],
      ['Коммунальные', 'Аренда (апрель)', 180000.00, '2026-04-05', null, null],
      ['Зарплата', 'Зарплата (апрель)', 479000.00, '2026-04-30', null, null],

      ['Продукты', 'Закупка овощей (май)', 14000.00, '2026-05-05', 'РК-040', 'ОвощеПром'],
      ['Продукты', 'Мясо и птица (май)', 52000.00, '2026-05-10', 'РК-041', 'МясоПром'],
      ['Маркетинг', 'Летняя акция', 30000.00, '2026-05-15', null, null],
      ['Зарплата', 'Зарплата (май)', 479000.00, '2026-05-31', null, null],
      ['Коммунальные', 'Аренда (май)', 180000.00, '2026-05-05', null, null],

      ['Продукты', 'Закупка (июнь)', 16000.00, '2026-06-05', 'РК-050', 'ОвощеПром'],
      ['Продукты', 'Мясо (июнь)', 52000.00, '2026-06-08', 'РК-051', 'МясоПром'],
      ['Продукты', 'Вина и напитки (июнь)', 70000.00, '2026-06-12', 'РК-052', 'ВиноТорг'],
      ['Коммунальные', 'Аренда (июнь)', 180000.00, '2026-06-05', null, null],
    ];

    for (final e in expenses) {
      await db.rawInsert(
        'INSERT INTO expenses (category, description, amount, expense_date, receipt_number, supplier) VALUES (?, ?, ?, ?, ?, ?)',
        e,
      );
    }
  }

  Future<void> _seedTips(Database db) async {
    final orders = await db.rawQuery("SELECT id, waiter_id, total_amount FROM orders WHERE status = 'Оплачен' ORDER BY id");
    int tipCount = 0;
    for (final order in orders) {
      if (order['waiter_id'] != null && (order['id'] as int) % 3 == 0 && tipCount < 300) {
        final amount = ((order['total_amount'] as double) * (0.05 + (order['id'] as int) % 10 * 0.01)).roundToDouble();
        if (amount > 0) {
          final orderDate = await db.rawQuery(
            'SELECT order_date FROM orders WHERE id = ?',
            [order['id']],
          );
          await db.rawInsert(
            'INSERT INTO tips (order_id, waiter_id, amount, created_at) VALUES (?, ?, ?, ?)',
            [order['id'], order['waiter_id'], amount, orderDate.isNotEmpty ? orderDate.first['order_date'] : DateTime.now().toIso8601String()],
          );
          tipCount++;
        }
      }
    }
  }

  Future<void> _seedPrimaryCustomers(Database db) async {
    final customers = [
      ['Алексей Смирнов', '+7-926-111-2233', 'alexey@mail.ru', 'Постоянный гость', 'Лактоза', 15, 45000.00, '2026-06-10'],
      ['Екатерина Волкова', '+7-926-222-3344', 'ekaterina@mail.ru', 'Предпочитает VIP зону', null, 28, 120000.00, '2026-06-12'],
      ['Дмитрий Козлов', '+7-926-333-4455', 'dmitry.k@mail.ru', 'Часто заказывает стейки', 'Глютен', 8, 32000.00, '2026-06-08'],
      ['Ольга Петрова', '+7-926-444-5566', 'olga.p@mail.ru', 'Вегетарианец', null, 5, 18000.00, '2026-06-11'],
      ['Сергей Иванов', '+7-926-555-6677', 'sergey@mail.ru', 'Бизнес ланчи по пятницам', null, 42, 95000.00, '2026-06-13'],
      ['Анна Морозова', '+7-926-666-7788', 'anna.m@mail.ru', 'Юбилей 15 июля', 'Орехи', 12, 55000.00, '2026-06-05'],
      ['Павел Новиков', '+7-926-777-8899', null, 'Новый клиент', null, 2, 6500.00, '2026-06-09'],
      ['Марина Соколова', '+7-926-888-9900', 'marina@mail.ru', 'Заказывает доставку', null, 18, 72000.00, '2026-06-12'],
    ];

    for (final c in customers) {
      await db.rawInsert(
        'INSERT INTO customers (name, phone, email, notes, allergies, visit_count, total_spent, last_visit) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        c,
      );
    }
  }

  Future<void> _seedInventory(Database db) async {
    final inventory = [
      ['Говядина мраморная', 'Мясо', 'кг', 15.5, 5.0, 30.0, 1200.00, 'МясоПром'],
      ['Лосось свежий', 'Рыба', 'кг', 8.0, 3.0, 20.0, 1800.00, 'РыбаТорг'],
      ['Свинина вырезка', 'Мясо', 'кг', 12.0, 5.0, 25.0, 650.00, 'МясоПром'],
      ['Куриное филе', 'Мясо', 'кг', 20.0, 8.0, 40.0, 380.00, 'МясоПром'],
      ['Помидоры', 'Овощи', 'кг', 25.0, 10.0, 50.0, 120.00, 'ОвощеПром'],
      ['Огурцы', 'Овощи', 'кг', 18.0, 8.0, 40.0, 90.00, 'ОвощеПром'],
      ['Лук репчатый', 'Овощи', 'кг', 30.0, 10.0, 50.0, 45.00, 'ОвощеПром'],
      ['Картофель', 'Овощи', 'кг', 40.0, 15.0, 80.0, 35.00, 'ОвощеПром'],
      ['Сливки 33%', 'Молочные', 'л', 10.0, 5.0, 20.0, 180.00, 'МолочныйДом'],
      ['Сыр пармезан', 'Молочные', 'кг', 5.0, 2.0, 10.0, 2200.00, 'МолочныйДом'],
      ['Маскарпоне', 'Молочные', 'кг', 6.0, 3.0, 12.0, 850.00, 'МолочныйДом'],
      ['Мука', 'Бакалея', 'кг', 25.0, 10.0, 50.0, 60.00, 'СпецииМира'],
      ['Рис басмати', 'Бакалея', 'кг', 15.0, 5.0, 30.0, 180.00, 'СпецииМира'],
      ['Спагетти', 'Бакалея', 'кг', 20.0, 8.0, 40.0, 120.00, 'СпецииМира'],
      ['Оливковое масло', 'Бакалея', 'л', 8.0, 3.0, 15.0, 650.00, 'СпецииМира'],
      ['Вино белое', 'Напитки', 'бут.', 24.0, 10.0, 50.0, 800.00, 'ВиноТорг'],
      ['Вино красное', 'Напитки', 'бут.', 30.0, 10.0, 50.0, 900.00, 'ВиноТорг'],
      ['Вода минеральная', 'Напитки', 'бут.', 48.0, 20.0, 80.0, 60.00, 'Оптовик'],
    ];

    for (final i in inventory) {
      await db.rawInsert(
        'INSERT INTO inventory (name, category, unit, current_stock, min_stock, max_stock, cost_per_unit, supplier) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        i,
      );
    }
  }

  Future<void> _seedReservations(Database db) async {
    final reservations = [
      [null, 'Анна Смирнова', '+7-926-111-1111', '2026-06-28 19:00', 4, 'Подтверждено', 'День рождения'],
      [5, 'Сергей Иванов', '+7-926-555-6677', '2026-06-29 20:00', 6, 'Подтверждено', 'Бизнес-ужин'],
      [12, 'Екатерина Волкова', '+7-926-222-3344', '2026-06-30 18:00', 3, 'Подтверждено', 'VIP'],
      [9, 'Алексей Кузнецов', '+7-903-100-2001', '2026-07-01 19:30', 5, 'Подтверждено', 'Летняя веранда'],
      [11, 'Денис Новиков', '+7-903-100-2013', '2026-07-02 17:00', 10, 'Подтверждено', 'Корпоратив'],
      [13, 'Оксана Новикова', '+7-903-100-2006', '2026-07-03 20:00', 4, 'Подтверждено', null],
      [1, 'Марина Соколова', '+7-926-888-9900', '2026-07-04 19:00', 2, 'Подтверждено', 'Романтический ужин'],
      [3, 'Артём Попов', '+7-903-100-2005', '2026-06-28 13:00', 4, 'Выполнено', 'Бизнес-ланч'],
      [7, 'Наталья Федорова', '+7-903-100-2002', '2026-06-27 18:00', 3, 'Выполнено', null],
      [6, 'Галина Павлова', '+7-903-100-2018', '2026-06-26 19:00', 6, 'Отменено', 'Перенесено на июль'],
      [10, 'Максим Орлов', '+7-903-100-2011', '2026-07-05 20:00', 8, 'Подтверждено', 'Юбилей'],
      [14, 'Кирилл Зайцев', '+7-903-100-2017', '2026-07-06 18:30', 2, 'Подтверждено', null],
      [4, 'Лидия Егорова', '+7-903-100-2020', '2026-07-07 19:00', 4, 'Подтверждено', 'Деловая встреча'],
      [8, 'Валентина Белова', '+7-903-100-2016', '2026-06-29 14:00', 2, 'Неявка', null],
      [2, 'Пётр Козлов', '+7-903-100-2015', '2026-07-08 19:30', 4, 'Подтверждено', 'Дегустация'],
    ];

    for (final r in reservations) {
      await db.rawInsert(
        'INSERT INTO reservations (table_id, customer_name, phone, reservation_date, party_size, status, notes) VALUES (?, ?, ?, ?, ?, ?, ?)',
        r,
      );
    }
  }

  Future<void> _seedShifts(Database db) async {
    final now = DateTime.now();
    for (int d = 0; d < 14; d++) {
      final date = now.subtract(Duration(days: d));
      // 3 shifts per day
      final shifts = [
        [1, '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')} 09:00', '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')} 17:00', 'Завершена'],
        [2, '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')} 12:00', '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')} 20:00', 'Завершена'],
        [5, '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')} 14:00', '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')} 23:00', 'Завершена'],
      ];
      for (final s in shifts) {
        await db.rawInsert(
          'INSERT INTO shifts (waiter_id, start_time, end_time, status) VALUES (?, ?, ?, ?)',
          s,
        );
      }
    }
  }

  Future<void> _recalculateCustomerStats(Database db) async {
    await db.execute('''
      UPDATE customers SET
        visit_count = (SELECT COUNT(*) FROM orders WHERE orders.customer_id = customers.id),
        total_spent = (SELECT COALESCE(SUM(total_amount), 0) FROM orders WHERE orders.customer_id = customers.id),
        last_visit = (SELECT MAX(order_date) FROM orders WHERE orders.customer_id = customers.id)
    ''');
  }

  Future<void> _seedSchedules(Database db) async {
    final schedules = [
      [1, '2026-06-23', '09:00', '18:00', 'Выполнена'],
      [2, '2026-06-23', '12:00', '22:00', 'Выполнена'],
      [3, '2026-06-23', '14:00', '23:00', 'Выполнена'],
      [1, '2026-06-24', '09:00', '18:00', 'Выполнена'],
      [2, '2026-06-24', '12:00', '22:00', 'Выполнена'],
      [5, '2026-06-24', '14:00', '23:00', 'Выполнена'],
      [1, '2026-06-25', '09:00', '18:00', 'Выполнена'],
      [3, '2026-06-25', '12:00', '22:00', 'Выполнена'],
      [5, '2026-06-25', '14:00', '23:00', 'Выполнена'],
      [1, '2026-06-26', '09:00', '18:00', 'Запланирована'],
      [2, '2026-06-26', '12:00', '22:00', 'Запланирована'],
      [3, '2026-06-26', '14:00', '23:00', 'Запланирована'],
    ];

    for (final s in schedules) {
      await db.rawInsert(
        'INSERT INTO waiter_schedules (waiter_id, date, start_time, end_time, status) VALUES (?, ?, ?, ?, ?)',
        s,
      );
    }
  }

  Future<void> execute(String sql, {List<dynamic>? arguments}) async {
    await database.execute(sql, arguments ?? []);
  }

  Future<List<Map<String, dynamic>>> query(String sql, {List<dynamic>? arguments}) async {
    return database.rawQuery(sql, arguments);
  }

  Future<Map<String, dynamic>?> queryOne(String sql, {List<dynamic>? arguments}) async {
    final rows = await query(sql, arguments: arguments);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<T> transaction<T>(Future<T> Function() action) async {
    return database.transaction((txn) async {
      return action();
    });
  }

  Future<int> insert(String table, Map<String, dynamic> values) async {
    return database.insert(table, values);
  }

  Future<int> update(String table, Map<String, dynamic> values, {String? where, List<dynamic>? whereArgs}) async {
    return database.update(table, values, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, {String? where, List<dynamic>? whereArgs}) async {
    return database.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
