import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/car_model.dart';
import '../models/user_spot.dart';
import 'db_service.dart';

class BackupResult {
  const BackupResult(this.success, this.message, {this.spotCount = 0});
  final bool success;
  final String message;
  final int spotCount;
}

class BackupService {
  static const _manifest = 'carspotter_manifest.json';
  static const _spots = 'spots.json';
  static const _version = 2;

  static Future<BackupResult> exportBackup() async {
    try {
      final spots = await DbService.getAllSpots();
      final archive = Archive();
      final records = <Map<String, dynamic>>[];
      for (final spot in spots) {
        await spot.carModel.load();
        final model = spot.carModel.value;
        await model?.brand.load();
        final image = File(spot.imagePath);
        if (!await image.exists()) {
          throw StateError('Foto mancante: ${spot.imagePath}');
        }
        final photoPath = 'photos/${p.basename(spot.imagePath)}';
        archive.addFile(
          ArchiveFile(
            photoPath,
            await image.length(),
            await image.readAsBytes(),
          ),
        );
        records.add({
          'photo': photoPath,
          'model': model?.name,
          'brand': model?.brand.value?.name,
          'date': spot.dateCaptured.toIso8601String(),
          'latitude': spot.latitude,
          'longitude': spot.longitude,
          'locationName': spot.locationName,
          'customColor': spot.customColor,
          'year': spot.year,
          'notes': spot.notes,
          'isRacing': spot.isRacing,
          'isFavorite': spot.isFavorite,
        });
      }
      final manifest = {
        'format': 'carspotter-backup',
        'version': _version,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'spotCount': records.length,
        'photoCount': records.length,
      };
      archive.addFile(
        ArchiveFile(_manifest, 0, utf8.encode(jsonEncode(manifest))),
      );
      archive.addFile(ArchiveFile(_spots, 0, utf8.encode(jsonEncode(records))));
      final bytes = ZipEncoder().encode(archive);
      if (bytes.isEmpty) throw StateError('ZIP non creato');
      final verification = ZipDecoder().decodeBytes(bytes);
      if (verification.findFile(_manifest) == null ||
          verification.findFile(_spots) == null) {
        throw StateError('ZIP non verificabile');
      }
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final target = await FilePicker.saveFile(
        dialogTitle: 'Salva backup CarSpotter',
        fileName: 'CarSpotter_Backup_$stamp.zip',
        bytes: Uint8List.fromList(bytes),
        mimeType: 'application/zip',
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
      return target == null
          ? const BackupResult(false, 'Salvataggio annullato')
          : BackupResult(true, 'Backup salvato', spotCount: records.length);
    } catch (e) {
      debugPrint('Backup export: $e');
      return const BackupResult(false, 'Impossibile creare un backup valido');
    }
  }

  static Future<BackupResult> importBackup() async {
    final importedIds = <int>[];
    final restoredPhotos = <File>[];
    try {
      final selected = await FilePicker.pickFile(
        dialogTitle: 'Scegli il backup CarSpotter',
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
      if (selected == null) {
        return const BackupResult(false, 'Importazione annullata');
      }
      final archive = ZipDecoder().decodeBytes(await selected.readAsBytes());
      final manifestFile = archive.findFile(_manifest);
      final spotsFile = archive.findFile(_spots);
      if (manifestFile == null || spotsFile == null) {
        throw const FormatException('Archivio non riconosciuto');
      }
      final manifest =
          jsonDecode(utf8.decode(manifestFile.content)) as Map<String, dynamic>;
      if (manifest['format'] != 'carspotter-backup' ||
          manifest['version'] != _version) {
        throw const FormatException('Versione non supportata');
      }
      final records = (jsonDecode(utf8.decode(spotsFile.content)) as List)
          .cast<Map<String, dynamic>>();
      if (records.length != manifest['spotCount']) {
        throw const FormatException('Conteggio non valido');
      }
      for (final item in records) {
        final photo = item['photo'] as String?;
        if (photo == null ||
            !photo.startsWith('photos/') ||
            archive.findFile(photo) == null ||
            item['model'] == null) {
          throw const FormatException('Backup incompleto');
        }
      }

      // Controllo completo prima di scrivere qualsiasi dato: un backup che
      // punta a un modello assente non deve produrre uno spot orfano.
      for (final item in records) {
        final model = await DbService.isar.carModels
            .filter()
            .nameEqualTo(item['model'] as String)
            .findFirst();
        if (model == null) {
          throw const FormatException(
            'Catalogo incompleto: sincronizzalo prima di importare',
          );
        }
      }

      final appDir = await getApplicationDocumentsDirectory();
      var imported = 0;
      for (final item in records) {
        final model = await DbService.isar.carModels
            .filter()
            .nameEqualTo(item['model'] as String)
            .findFirst();
        if (model == null) {
          throw StateError('Modello verificato ma non disponibile');
        }
        final source = archive.findFile(item['photo'] as String)!;
        final destination = File(
          p.join(
            appDir.path,
            'spot_import_${DateTime.now().microsecondsSinceEpoch}_$imported.jpg',
          ),
        );
        await destination.writeAsBytes(source.content, flush: true);
        restoredPhotos.add(destination);
        if (await destination.length() == 0) {
          throw const FormatException('Foto vuota');
        }
        final spot = UserSpot()
          ..imagePath = destination.path
          ..dateCaptured = DateTime.parse(item['date'] as String)
          ..latitude = (item['latitude'] as num?)?.toDouble()
          ..longitude = (item['longitude'] as num?)?.toDouble()
          ..locationName = item['locationName'] as String?
          ..customColor = item['customColor'] as String?
          ..year = item['year'] as int?
          ..notes = item['notes'] as String?
          ..isRacing = item['isRacing'] as bool? ?? false
          ..isFavorite = item['isFavorite'] as bool? ?? false;
        await DbService.isar.writeTxn(() async {
          await DbService.isar.userSpots.put(spot);
          spot.carModel.value = model;
          await spot.carModel.save();
        });
        importedIds.add(spot.id);
        imported++;
      }
      return BackupResult(
        true,
        'Importati $imported spot senza cancellare dati esistenti',
        spotCount: imported,
      );
    } catch (e) {
      // Rollback compensativo: il database e le foto non rimangono a metà se
      // lo ZIP, una foto o una scrittura falliscono durante l'importazione.
      if (importedIds.isNotEmpty) {
        await DbService.isar.writeTxn(() async {
          for (final id in importedIds) {
            await DbService.isar.userSpots.delete(id);
          }
        });
      }
      for (final photo in restoredPhotos) {
        if (await photo.exists()) {
          await photo.delete();
        }
      }
      debugPrint('Backup import: $e');
      return const BackupResult(false, 'Backup non valido o danneggiato');
    }
  }
}
