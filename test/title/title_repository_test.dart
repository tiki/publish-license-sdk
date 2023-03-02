/*
 * Copyright (c) TIKI Inc.
 * MIT license. See LICENSE file in root directory.
 */

import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:tiki_sdk_dart/cache/title/title_record.dart';
import 'package:tiki_sdk_dart/cache/title/title_repository.dart';
import 'package:tiki_sdk_dart/tiki_sdk.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('Title Repository Tests', () {
    test('getAll - Success', () {
      Database db = sqlite3.openInMemory();
      TitleRepository repository = TitleRepository(db);

      int numRecords = 3;
      for (int i = 0; i < numRecords; i++) {
        TitleRecord record = TitleRecord('com.mytiki.test', const Uuid().v4(),
            transactionId: Bytes.utf8Encode(const Uuid().v4()));
        repository.save(record);
      }

      List<TitleRecord> titles = repository.getAll();
      expect(titles.length, numRecords);
    });

    test('getByPtr - Success', () {
      Database db = sqlite3.openInMemory();
      TitleRepository repository = TitleRepository(db);

      int numRecords = 3;
      Map<String, String> ptrTidMap = {};
      for (int i = 0; i < numRecords; i++) {
        String ptr = const Uuid().v4();
        String tid = const Uuid().v4();
        ptrTidMap[ptr] = tid;
        TitleRecord record = TitleRecord('com.mytiki.test', ptr,
            transactionId: Bytes.utf8Encode(tid));
        repository.save(record);
      }

      for (int i = 0; i < numRecords; i++) {
        TitleRecord? title =
            repository.getByPtr(ptrTidMap.keys.elementAt(i), 'com.mytiki.test');
        expect(title != null, true);
        expect(Bytes.utf8Decode(title!.transactionId!),
            ptrTidMap.values.elementAt(i));
      }
    });
  });
}
