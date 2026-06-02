import 'package:csv/csv.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';

class CsvImportResult {
  const CsvImportResult({
    required this.entries,
    required this.errors,
  });

  final List<LedgerEntry> entries;
  final List<String> errors;
}

class LedgerCsvCodec {
  LedgerCsvCodec({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  static const headers = ['日期', '类型', '分类', '金额', '备注'];

  final Uuid _uuid;

  String encode(List<LedgerEntry> entries) {
    final rows = <List<Object?>>[
      headers,
      ...entries.map(
        (entry) => [
          _formatDate(entry.date),
          entry.type.label,
          entry.category,
          centsToDecimal(entry.amountCents),
          entry.note,
        ],
      ),
    ];

    return const ListToCsvConverter().convert(rows);
  }

  CsvImportResult decode(String content) {
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
    ).convert(content);

    if (rows.isEmpty) {
      return const CsvImportResult(entries: [], errors: ['CSV 文件为空']);
    }

    final entries = <LedgerEntry>[];
    final errors = <String>[];
    final dataRows = _looksLikeHeader(rows.first) ? rows.skip(1) : rows;

    var rowNumber = _looksLikeHeader(rows.first) ? 2 : 1;
    for (final row in dataRows) {
      final parsed = _parseRow(row, rowNumber);
      if (parsed.entry != null) {
        entries.add(parsed.entry!);
      }
      if (parsed.error != null) {
        errors.add(parsed.error!);
      }
      rowNumber += 1;
    }

    return CsvImportResult(entries: entries, errors: errors);
  }

  _ParsedRow _parseRow(List<dynamic> row, int rowNumber) {
    if (row.length < 4) {
      return _ParsedRow(error: '第 $rowNumber 行列数不足');
    }

    final date = DateTime.tryParse(row[0].toString().trim());
    if (date == null) {
      return _ParsedRow(error: '第 $rowNumber 行日期格式错误，请使用 YYYY-MM-DD');
    }

    final typeText = row[1].toString().trim();
    final type = switch (typeText) {
      '收入' || 'income' || 'Income' => EntryType.income,
      '支出' || 'expense' || 'Expense' => EntryType.expense,
      _ => null,
    };
    if (type == null) {
      return _ParsedRow(error: '第 $rowNumber 行类型必须是 收入 或 支出');
    }

    final category = row[2].toString().trim();
    if (category.isEmpty) {
      return _ParsedRow(error: '第 $rowNumber 行分类不能为空');
    }

    final amountCents = decimalToCents(row[3].toString());
    if (amountCents == null || amountCents <= 0) {
      return _ParsedRow(error: '第 $rowNumber 行金额必须大于 0');
    }

    return _ParsedRow(
      entry: LedgerEntry(
        id: _uuid.v4(),
        type: type,
        amountCents: amountCents,
        category: category,
        date: date,
        note: row.length > 4 ? row[4].toString().trim() : '',
        createdAt: DateTime.now(),
      ),
    );
  }

  bool _looksLikeHeader(List<dynamic> row) {
    if (row.length < headers.length) {
      return false;
    }
    return row
        .take(headers.length)
        .map((cell) => cell.toString().trim())
        .toList()
        .join(',') ==
        headers.join(',');
  }
}

class _ParsedRow {
  const _ParsedRow({this.entry, this.error});

  final LedgerEntry? entry;
  final String? error;
}

int? decimalToCents(String value) {
  final normalized = value.trim().replaceAll(',', '');
  if (normalized.isEmpty) {
    return null;
  }

  final amount = double.tryParse(normalized);
  if (amount == null) {
    return null;
  }

  return (amount * 100).round();
}

String centsToDecimal(int cents) {
  return (cents / 100).toStringAsFixed(2);
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
