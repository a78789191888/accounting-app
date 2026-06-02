import 'package:flutter/material.dart';

import 'src/app.dart';
import 'src/ledger_controller.dart';
import 'src/storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = LedgerController(store: LedgerStore());
  await controller.load();

  runApp(AccountingApp(controller: controller));
}
