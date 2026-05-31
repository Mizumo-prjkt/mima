import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor openConnection() {
  return WebDatabase('mima_db');
}
// For drift >= 2.x, WebDatabase is a standard class that works out-of-the-box.
