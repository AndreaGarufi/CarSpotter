import 'dart:io';
import 'package:flutter/foundation.dart'; // <-- Aggiunto per usare debugPrint in modo sicuro
import 'package:archive/archive_io.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'db_service.dart';

class BackupService {
  static Future<bool> exportBackup() async {
    try {
      // 1. Troviamo la cartella temporanea del dispositivo
      final tempDir = await getTemporaryDirectory();
      final zipFilePath = p.join(tempDir.path, 'CarSpotter_Backup.zip');

      final oldZip = File(zipFilePath);
      if (await oldZip.exists()) {
        await oldZip.delete();
      }

      // 2. CREIAMO UNA COPIA SICURA DEL DATABASE
      final isar = DbService.isar;
      final safeDbBackupPath = p.join(tempDir.path, 'database_backup.isar');
      final safeDbFile = File(safeDbBackupPath);

      if (await safeDbFile.exists()) {
        await safeDbFile.delete();
      }
      await isar.copyToFile(safeDbBackupPath);

      // 3. Inizializziamo il motore ZIP
      final encoder = ZipFileEncoder();
      encoder.create(zipFilePath);
      encoder.addFile(safeDbFile, 'database/car_spotter.isar');

      // 4. Aggiungiamo tutte le foto fisiche
      final spots = await DbService.getAllSpots();
      for (var spot in spots) {
        if (spot.imagePath.isNotEmpty) {
          final imgFile = File(spot.imagePath);
          if (await imgFile.exists()) {
            final fileName = p.basename(spot.imagePath);
            encoder.addFile(imgFile, 'photos/$fileName');
          }
        }
      }
      encoder.close();

      // Pulizia temporanea
      if (await safeDbFile.exists()) {
        await safeDbFile.delete();
      }

      // ==========================================
      // 5. SALVATAGGIO DIRETTO IN "DOWNLOAD" (ANDROID)
      // ==========================================
      if (Platform.isAndroid) {
        try {
          // Punta alla cartella pubblica "Download" standard di Android
          final downloadDir = Directory('/storage/emulated/0/Download');
          if (await downloadDir.exists()) {
            final savedZipPath = p.join(
              downloadDir.path,
              'CarSpotter_Backup.zip',
            );
            final savedZip = File(savedZipPath);
            if (await savedZip.exists()) {
              await savedZip
                  .delete(); // Cancella backup precedenti per non creare duplicati
            }
            // Copia fisicamente lo ZIP finale
            await File(zipFilePath).copy(savedZipPath);

            // 👇 Ora usiamo debugPrint invece del vecchio print
            debugPrint("✅ Backup copiato con successo nei Download!");
          }
        } catch (e) {
          debugPrint("⚠️ Salvataggio in Download fallito in background: $e");
        }
      }

      // ==========================================
      // 6. APERTURA MENU CONDIVISIONE AGGIORNATA
      // ==========================================
      // 👇 Utilizziamo la sintassi raccomandata per la libreria share_plus moderna
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(zipFilePath)],
          text: 'Ecco il backup completo del mio Garage di Car Spotter! 🏎️📦',
        ),
      );

      return true;
    } catch (e) {
      debugPrint("Errore Backup Dettagliato: $e");
      return false;
    }
  }
}
