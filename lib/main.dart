import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await openDatabase(
    join(await getDatabasesPath(), 'monthly_expense.db'),
    onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE transactions(id INTEGER PRIMARY KEY AUTOINCREMENT, details TEXT, amount REAL, month TEXT)',
      );
    },
    version: 1,
  );
  runApp(MyApp(database: database));
}

class MyApp extends StatelessWidget {
  final Database database;
  MyApp({required this.database});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monthly Expense Tracker',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ExpenseHomePage(database: database),
    );
  }
}

class ExpenseHomePage extends StatefulWidget {
  final Database database;
  ExpenseHomePage({required this.database});

  @override
  _ExpenseHomePageState createState() => _ExpenseHomePageState();
}

class _ExpenseHomePageState extends State<ExpenseHomePage> {
  DateTime selectedMonth = DateTime.now();
  final _detailsController = TextEditingController();
  final _amountController = TextEditingController();
  List<Map<String, dynamic>> transactions = [];

  double totalEarn = 0;
  double totalExpense = 0;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final monthString = DateFormat('yyyy-MM').format(selectedMonth);
    final List<Map<String, dynamic>> data = await widget.database.query(
      'transactions',
      where: 'month = ?',
      whereArgs: [monthString],
    );

    double earn = 0;
    double expense = 0;
    for (var tx in data) {
      if (tx['amount'] >= 0) {
        earn += tx['amount'];
      } else {
        expense += tx['amount'].abs();
      }
    }

    setState(() {
      transactions = data;
      totalEarn = earn;
      totalExpense = expense;
    });
  }

  Future<void> _addTransaction() async {
    String details = _detailsController.text;
    double amount = double.tryParse(_amountController.text) ?? 0;
    if (details.isEmpty || amount == 0) return;

    final monthString = DateFormat('yyyy-MM').format(selectedMonth);

    await widget.database.insert('transactions', {
      'details': details,
      'amount': amount,
      'month': monthString,
    });

    _detailsController.clear();
    _amountController.clear();
    _loadTransactions();
  }

  Future<void> _pickMonth() async {
    DateTime? picked = await showDatePicker(
        context: context,
        initialDate: selectedMonth,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        selectableDayPredicate: (day) => day.day == 1);

    if (picked != null) {
      setState(() {
        selectedMonth = DateTime(picked.year, picked.month);
      });
      _loadTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    double balance = totalEarn - totalExpense;

    return Scaffold(
      appBar: AppBar(title: Text('Monthly Expense Tracker')),
      body: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            // Top 3 boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _infoBox('Earn', totalEarn, Colors.green[200]!),
                _infoBox('Expense', totalExpense, Colors.red[200]!),
                _infoBox('Balance', balance, Colors.blue[200]!),
              ],
            ),
            SizedBox(height: 12),

            // Month selector
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Month: ${DateFormat.yMMM().format(selectedMonth)}',
                    style: TextStyle(fontSize: 16)),
                SizedBox(width: 10),
                ElevatedButton(onPressed: _pickMonth, child: Text('Select Month')),
              ],
            ),
            SizedBox(height: 12),

            // Add transaction section
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _detailsController,
                    decoration: InputDecoration(labelText: 'Details'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    decoration: InputDecoration(labelText: 'Amount'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                IconButton(onPressed: _addTransaction, icon: Icon(Icons.add))
              ],
            ),
            SizedBox(height: 12),

            // Transaction List
            Expanded(
              child: transactions.isEmpty
                  ? Center(child: Text('No transactions'))
                  : ListView.builder(
                      itemCount: transactions.length,
                      itemBuilder: (ctx, index) {
                        final tx = transactions[index];
                        return Card(
                          child: ListTile(
                            title: Text(tx['details']),
                            subtitle: Text(tx['month']),
                            trailing:
                                Text(tx['amount'].toStringAsFixed(2)),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBox(String title, double amount, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration:
          BoxDecoration(borderRadius: BorderRadius.circular(8), color: color),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 16)),
          SizedBox(height: 4),
          Text(amount.toStringAsFixed(2),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
