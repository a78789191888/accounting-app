import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'csv_codec.dart';
import 'ledger_controller.dart';
import 'models.dart';

class AccountingApp extends StatelessWidget {
  const AccountingApp({super.key, required this.controller});

  final LedgerController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '轻记账',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6BFF)),
        useMaterial3: true,
      ),
      home: LedgerHome(controller: controller),
    );
  }
}

class LedgerHome extends StatefulWidget {
  const LedgerHome({super.key, required this.controller});

  final LedgerController controller;

  @override
  State<LedgerHome> createState() => _LedgerHomeState();
}

class _LedgerHomeState extends State<LedgerHome> {
  final _searchController = TextEditingController();

  LedgerController get controller => widget.controller;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('轻记账'),
            actions: [
              IconButton(
                tooltip: '导入 CSV',
                onPressed: controller.isBusy ? null : _importCsv,
                icon: const Icon(Icons.file_upload_outlined),
              ),
              IconButton(
                tooltip: '导出 CSV',
                onPressed: controller.filteredEntries.isEmpty
                    ? null
                    : controller.exportCsv,
                icon: const Icon(Icons.ios_share_outlined),
              ),
            ],
          ),
          body: controller.isBusy
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      _MonthPicker(controller: controller),
                      const SizedBox(height: 12),
                      _SummaryPanel(controller: controller),
                      const SizedBox(height: 12),
                      _FilterBar(
                        controller: controller,
                        searchController: _searchController,
                      ),
                      const SizedBox(height: 12),
                      if (controller.filteredEntries.isEmpty)
                        const _EmptyState()
                      else
                        ...controller.filteredEntries.map(
                          (entry) => _EntryCard(
                            entry: entry,
                            onTap: () => _showEntrySheet(entry: entry),
                            onDelete: () => controller.deleteEntry(entry.id),
                          ),
                        ),
                    ],
                  ),
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showEntrySheet(),
            icon: const Icon(Icons.add),
            label: const Text('记一笔'),
          ),
        );
      },
    );
  }

  Future<void> _importCsv() async {
    final result = await controller.importCsv();
    if (!mounted || result == null) {
      return;
    }

    final message = result.errors.isEmpty
        ? '已导入 ${result.entries.length} 条账单'
        : '已导入 ${result.entries.length} 条，${result.errors.length} 条失败';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

    if (result.errors.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('导入提示'),
          content: SingleChildScrollView(
            child: Text(result.errors.take(12).join('\n')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showEntrySheet({LedgerEntry? entry}) async {
    final result = await showModalBottomSheet<LedgerEntryFormResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _EntryFormSheet(
        initialEntry: entry,
        categories: controller.categories,
      ),
    );

    if (result == null) {
      return;
    }

    if (entry == null) {
      await controller.addEntry(
        type: result.type,
        amountCents: result.amountCents,
        category: result.category,
        date: result.date,
        note: result.note,
      );
    } else {
      await controller.updateEntry(
        entry.copyWith(
          type: result.type,
          amountCents: result.amountCents,
          category: result.category,
          date: result.date,
          note: result.note,
        ),
      );
    }
  }
}

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({required this.controller});

  final LedgerController controller;

  @override
  Widget build(BuildContext context) {
    final monthText = DateFormat('yyyy 年 MM 月').format(controller.selectedMonth);

    return Row(
      children: [
        IconButton(
          onPressed: controller.previousMonth,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Center(
            child: Text(
              monthText,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ),
        IconButton(
          onPressed: controller.nextMonth,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.controller});

  final LedgerController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.monthlySummary;
    final colorScheme = Theme.of(context).colorScheme;
    final categoryStats = controller.expenseByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: '收入',
                value: formatMoney(summary.incomeCents),
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                label: '支出',
                value: formatMoney(summary.expenseCents),
                color: colorScheme.error,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricCard(
                label: '结余',
                value: formatMoney(summary.balanceCents),
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '本月预算',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showBudgetDialog(context),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('设置'),
                    ),
                  ],
                ),
                Text(
                  summary.budgetCents <= 0
                      ? '未设置预算'
                      : '剩余 ${formatMoney(summary.remainingBudgetCents)} / '
                            '${formatMoney(summary.budgetCents)}',
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: summary.budgetUsage),
              ],
            ),
          ),
        ),
        if (categoryStats.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '分类支出',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  ...categoryStats.take(5).map(
                    (entry) => _CategoryRow(
                      category: entry.key,
                      amountCents: entry.value,
                      totalCents: summary.expenseCents,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _showBudgetDialog(BuildContext context) async {
    final amountController = TextEditingController(
      text: centsToDecimal(controller.monthlySummary.budgetCents),
    );

    final amount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置本月预算'),
        content: TextField(
          controller: amountController,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '预算金额',
            prefixText: '¥ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final cents = decimalToCents(amountController.text);
              if (cents == null || cents < 0) {
                return;
              }
              Navigator.of(context).pop(cents);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    amountController.dispose();
    if (amount != null) {
      await controller.saveBudget(amount);
    }
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.amountCents,
    required this.totalCents,
  });

  final String category;
  final int amountCents;
  final int totalCents;

  @override
  Widget build(BuildContext context) {
    final usage = totalCents <= 0 ? 0.0 : amountCents / totalCents;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(category)),
              Text(formatMoney(amountCents)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(value: usage.clamp(0.0, 1.0).toDouble()),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.controller,
    required this.searchController,
  });

  final LedgerController controller;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: searchController,
          onChanged: controller.setQuery,
          decoration: InputDecoration(
            hintText: '搜索分类或备注',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: controller.query.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      searchController.clear();
                      controller.setQuery('');
                    },
                    icon: const Icon(Icons.clear),
                  ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('全部'),
              selected: controller.typeFilter == null,
              onSelected: (_) => controller.setTypeFilter(null),
            ),
            ChoiceChip(
              label: const Text('支出'),
              selected: controller.typeFilter == EntryType.expense,
              onSelected: (_) => controller.setTypeFilter(EntryType.expense),
            ),
            ChoiceChip(
              label: const Text('收入'),
              selected: controller.typeFilter == EntryType.income,
              onSelected: (_) => controller.setTypeFilter(EntryType.income),
            ),
          ],
        ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.onTap,
    required this.onDelete,
  });

  final LedgerEntry entry;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isExpense = entry.type == EntryType.expense;
    final amountPrefix = isExpense ? '-' : '+';
    final amountColor = isExpense ? Theme.of(context).colorScheme.error : Colors.green;

    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.errorContainer,
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            child: Icon(isExpense ? Icons.remove : Icons.add),
          ),
          title: Text(entry.category),
          subtitle: Text(
            [
              DateFormat('yyyy-MM-dd').format(entry.date),
              if (entry.note.isNotEmpty) entry.note,
            ].join(' · '),
          ),
          trailing: Text(
            '$amountPrefix${formatMoney(entry.amountCents)}',
            style: TextStyle(
              color: amountColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            const Text('这个月份还没有账单'),
            const SizedBox(height: 4),
            Text(
              '点右下角“记一笔”开始记录。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryFormSheet extends StatefulWidget {
  const _EntryFormSheet({
    required this.categories,
    this.initialEntry,
  });

  final LedgerEntry? initialEntry;
  final List<String> categories;

  @override
  State<_EntryFormSheet> createState() => _EntryFormSheetState();
}

class _EntryFormSheetState extends State<_EntryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late EntryType _type;
  late DateTime _date;
  late TextEditingController _amountController;
  late TextEditingController _categoryController;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    _type = entry?.type ?? EntryType.expense;
    _date = entry?.date ?? DateTime.now();
    _amountController = TextEditingController(
      text: entry == null ? '' : centsToDecimal(entry.amountCents),
    );
    _categoryController = TextEditingController(text: entry?.category ?? '');
    _noteController = TextEditingController(text: entry?.note ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.initialEntry == null ? '新增账单' : '编辑账单',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SegmentedButton<EntryType>(
              segments: const [
                ButtonSegment(value: EntryType.expense, label: Text('支出')),
                ButtonSegment(value: EntryType.income, label: Text('收入')),
              ],
              selected: {_type},
              onSelectionChanged: (value) {
                setState(() => _type = value.first);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '金额',
                prefixText: '¥ ',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final cents = decimalToCents(value ?? '');
                if (cents == null || cents <= 0) {
                  return '请输入大于 0 的金额';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _categoryController,
              decoration: InputDecoration(
                labelText: '分类',
                border: const OutlineInputBorder(),
                suffixIcon: widget.categories.isEmpty
                    ? null
                    : PopupMenuButton<String>(
                        icon: const Icon(Icons.arrow_drop_down),
                        onSelected: (value) => _categoryController.text = value,
                        itemBuilder: (context) => [
                          for (final category in widget.categories)
                            PopupMenuItem(value: category, child: Text(category)),
                        ],
                      ),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return '请输入分类';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_outlined),
              label: Text(DateFormat('yyyy-MM-dd').format(_date)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      LedgerEntryFormResult(
        type: _type,
        amountCents: decimalToCents(_amountController.text)!,
        category: _categoryController.text.trim(),
        date: _date,
        note: _noteController.text.trim(),
      ),
    );
  }
}

class LedgerEntryFormResult {
  const LedgerEntryFormResult({
    required this.type,
    required this.amountCents,
    required this.category,
    required this.date,
    required this.note,
  });

  final EntryType type;
  final int amountCents;
  final String category;
  final DateTime date;
  final String note;
}

String formatMoney(int cents) {
  final sign = cents < 0 ? '-' : '';
  final amount = (cents.abs() / 100).toStringAsFixed(2);
  return '$sign¥$amount';
}
