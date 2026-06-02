import 'package:dsmfh_accounting/src/csv_codec.dart';
import 'package:dsmfh_accounting/src/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('encodes and decodes ledger entries', () {
    final codec = LedgerCsvCodec();
    final entry = LedgerEntry(
      id: 'entry-1',
      type: EntryType.expense,
      amountCents: 12345,
      category: '餐饮',
      date: DateTime(2026, 6, 2),
      note: '午餐',
      createdAt: DateTime(2026, 6, 2),
    );

    final encoded = codec.encode([entry]);
    final decoded = codec.decode(encoded);

    expect(decoded.errors, isEmpty);
    expect(decoded.entries, hasLength(1));
    expect(decoded.entries.single.type, EntryType.expense);
    expect(decoded.entries.single.amountCents, 12345);
    expect(decoded.entries.single.category, '餐饮');
    expect(decoded.entries.single.note, '午餐');
  });

  test('reports invalid rows', () {
    final codec = LedgerCsvCodec();

    final decoded = codec.decode('日期,类型,分类,金额,备注\nbad,支出,餐饮,10,备注');

    expect(decoded.entries, isEmpty);
    expect(decoded.errors.single, contains('日期格式错误'));
  });

  test('converts decimal money to cents', () {
    expect(decimalToCents('12.34'), 1234);
    expect(decimalToCents('1,234.56'), 123456);
    expect(decimalToCents('abc'), isNull);
  });
}
