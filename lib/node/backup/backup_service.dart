/*
 * Copyright (c) TIKI Inc.
 * MIT license. See LICENSE file in root directory.
 */
/// The backup library for node service.
/// {@category Node}
library backup;

import 'dart:convert';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import '../../utils/utils.dart';
import '../node_service.dart';
import 'backup_storage_interface.dart';

export 'backup_model.dart';
export 'backup_repository.dart';

/// A service to handle the backup requests to remote backup.
///
/// The remote backup implementation should follow the key-value interface defined
/// in [BackupStorageInterface]. This service does not do any security checks.
/// It is up to the implementation of [BackupStorageInterface] to implement it.
class BackupService {
  /// The local database repository for backup requests.
  final BackupRepository _repository;

  /// The remote storage for backups.
  final BackupStorageInterface _storage;

  /// The chain [KeyModel]
  final KeyModel _key;

  /// The function to get a [BlockModel] by its [BlockModel.id].
  final Uint8List? Function(Uint8List) _getBlock;

  /// Initializes a [BackupService] and backs up the public key for the chain.
  BackupService(this._storage, Database database, this._key, this._getBlock)
      : _repository = BackupRepository(database) {
    String keyBackupPath = '${base64UrlEncode(_key.address)}/public.key';
    BackupModel? keyBackup = _repository.getByPath(keyBackupPath);

    if (keyBackup == null) {
      keyBackup = BackupModel(path: keyBackupPath);
      _repository.save(keyBackup);
    }

    if (keyBackup.timestamp == null) {
      Uint8List obj = base64.decode(_key.privateKey.public.encode());
      _storage.write('${base64UrlEncode(_key.address)}/public.key', obj);
      keyBackup.timestamp = DateTime.now();
      _repository.update(keyBackup);
    }

    _pending();
  }

  /// Creates a backup request for a [BlockModel] by its [id] and process pending
  /// backups.
  Future<void> block(Uint8List id) async {
    String b64address = base64UrlEncode(_key.address);
    BackupModel bkpModel =
        BackupModel(path: '$b64address/${base64UrlEncode(id)}.block');
    _repository.save(bkpModel);
    return _pending();
  }

  Future<void> _pending() async {
    String b64address = base64UrlEncode(_key.address);
    List<BackupModel> pending = _repository.getPending();
    if (pending.isNotEmpty) {
      for (BackupModel backup in pending) {
        if (backup.path.startsWith(b64address)) {
          String noAddress = backup.path.replaceFirst('$b64address/', '');
          String id = noAddress.substring(0, noAddress.length - 6);
          Uint8List? block = _getBlock(base64Decode(id));
          if (block != null) {
            Uint8List signature = UtilsRsa.sign(_key.privateKey, block);
            Uint8List signedBlock = (BytesBuilder()
                  ..add(UtilsCompactSize.encode(signature))
                  ..add(UtilsCompactSize.encode(block)))
                .toBytes();
            await _storage.write(backup.path, signedBlock);
            backup.timestamp = DateTime.now();
            _repository.update(backup);
          }
        }
      }
    }
  }
}
