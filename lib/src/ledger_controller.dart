import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import 'csv_codec.dart';
import 'models.dart';
import 'storage.dart';

class LedgerController extends ChangeNotifier {
  LedgerController({
    required LedgerStore store,
    LedgerCsvCodec? csvCodec,
    Uuid? uuid,
  }) : _store = store,
       _csvCodec = csvCodec ?? LedgerCsvCodec(uuid: uuid),
       _uuid = uuid ?? const Uuid();

  final LedgerStore _store;
  final LedgerCsvCodec _csvCodec;
  final Uuid _uuid;

  List<LedgerEntry> _entries = [];
  List<MonthlyBudget> _budgets = [];
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  EntryType? _typeFilter;
  String _query = '';
  bool _isBusy = false;

  List<LedgerEntry> get entries => List.unmodifiable(_entries);
  List<MonthlyBudget> get budgets => List.unmodifiable(_budgets);
  DateTime get selectedMonth => _selectedMonth;
  EntryType? get typeFilter => _typeFilter;
  String get query => _query;
  bool get isBusy => _isBusy;

  String get selectedMonthKey => monthKeyFromDate(_selectedMonth);

  List<String> get categories {
    final values = _entries.map((entry) => entry.category).toSet().toList();
    values.sort();
    return values;
  }

  List<LedgerEntry> get monthEntries {
    return _entries
        .where((entry) => monthKeyFromDate(entry.date) == selectedMonthKey)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<LedgerEntry> get filteredEntries {
    final normalizedQuery = _query.trim().toLowerCase();
    return monthEntries.where((entry) {
      final matchesType = _typeFilter == null || entry.type == _typeFilter;
      final matchesQuery =
          normalizedQuery.isEmpty ||
          entry.category.toLowerCase().contains(normalizedQuery) ||
          entry.note.toLowerCase().contains(normalizedQuery);
      return matchesType && matchesQuery;
    }).toList();
  }

  MonthlySummary get monthlySummary {
    var incomeCents = 0;
    var expenseCents = 0;

    for (final entry in monthEntries) {
      if (entry.type == EntryType.income) {
        incomeCents += entry.amountCents;
      } else {
        expenseCents += entry.amountCents;
      }
    }

    return MonthlySummary(
      incomeCents: incomeCents,
      expenseCents: expenseCents,
      budgetCents: budgetForMonth(selectedMonthKey),
    );
  }

  Map<String, int> get expenseByCategory {
    final result = <String, int>{};
    for (final entry in monthEntries) {
      if (entry.type != EntryType.expense) {
        continue;
      }
      result.update(
        entry.category,
        (value) => value + entry.amountCents,
        ifAbsent: () => entry.amountCents,
      );
    }
    return result;
  }

  Future<void> load() async {
    _setBusy(true);
    final data = await _store.load();
    _entries = data.entries;
    _budgets = data.budgets;
    _setBusy(false);
  }

  Future<void> addEntry({
    required EntryType type,
    required int amountCents,
    required String category,
    required DateTime date,
    required String note,
  }) async {
    _entries = [
      LedgerEntry(
        id: _uuid.v4(),
        type: type,
        amountCents: amountCents,
        category: category.trim(),
        date: date,
        note: note.trim(),
        createdAt: DateTime.now(),
      ),
      ..._entries,
    ];
    await _persist();
  }

  Future<void> updateEntry(LedgerEntry updated) async {
    _entries = [
      for (final entry in _entries)
        if (entry.id == updated.id) updated else entry,
    ];
    await _persist();
  }

  Future<void> deleteEntry(String id) async {
    _entries = _entries.where((entry) => entry.id != id).toList();
    await _persist();
  }

  Future<void> saveBudget(int amountCents) async {
    final budget = MonthlyBudget(
      monthKey: selectedMonthKey,
      amountCents: amountCents,
    );
    final index = _budgets.indexWhere(
      (item) => item.monthKey == selectedMonthKey,
    );
    if (index == -1) {
      _budgets = [..._budgets, budget];
    } else {
      _budgets = [
        for (final item in _budgets)
          if (item.monthKey == selectedMonthKey) budget else item,
      ];
    }
    await _persist();
  }

  int budgetForMonth(String monthKey) {
    for (final budget in _budgets) {
      if (budget.monthKey == monthKey) {
        return budget.amountCents;
      }
    }
    return 0;
  }

  void previousMonth() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    notifyListeners();
  }

  void nextMonth() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    notifyListeners();
  }

  void setTypeFilter(EntryType? type) {
    _typeFilter = type;
    notifyListeners();
  }

  void setQuery(String query) {
    _query = query;
    notifyListeners();
  }

  Future<CsvImportResult?> importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) {
      return null;
    }

    final bytes = file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) {
      return const CsvImportResult(
        entries: [],
        errors: ['无法读取所选 CSV 文件'],
      );
    }

    final decoded = utf8.decode(bytes, allowMalformed: true);
    final importResult = _csvCodec.decode(decoded);
    if (importResult.entries.isNotEmpty) {
      _entries = [...importResult.entries, ..._entries];
      await _persist();
    }
    return importResult;
  }

  Future<void> exportCsv() async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/账单-$selectedMonthKey.csv');
    await file.writeAsString(
      _csvCodec.encode(filteredEntries),
      encoding: utf8,
      flush: true,
    );

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        text: '账单导出 $selectedMonthKey',
      ),
    );
  }

  Future<void> _persist() async {
    await _store.save(LedgerData(entries: _entries, budgets: _budgets));
    notifyListeners();
  }

  void _setBusy(bool isBusy) {
    _isBusy = isBusy;
    notifyListeners();
  }
}
