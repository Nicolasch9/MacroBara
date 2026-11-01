//
//  ICloudSyncService.swift
//  MacroBara
//

import Foundation
import SwiftUI

@Observable
final class ICloudSyncService {
    static let shared = ICloudSyncService()
    
    private let bookmarkKey = "iCloudAutomazioneFolderBookmark"
    private let folderNameKey = "iCloudAutomazioneFolderName"
    private let lastSyncKey = "iCloudLastHealthSyncTimestamp"
    
    var lastSyncDate: Date? {
        didSet {
            if let d = lastSyncDate {
                UserDefaults.standard.set(d.timeIntervalSince1970, forKey: lastSyncKey)
            }
        }
    }
    
    var configuredFolderName: String? {
        UserDefaults.standard.string(forKey: folderNameKey)
    }
    
    var isFolderLinked: Bool {
        UserDefaults.standard.data(forKey: bookmarkKey) != nil
    }
    
    var statusMessage: String = ""
    var isSyncing: Bool = false
    
    init() {
        let ts = UserDefaults.standard.double(forKey: lastSyncKey)
        if ts > 0 {
            self.lastSyncDate = Date(timeIntervalSince1970: ts)
        }
    }
    
    func linkFolder(url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            statusMessage = "Accesso alla cartella non consentito."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let bookmark = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
            UserDefaults.standard.set(url.lastPathComponent, forKey: folderNameKey)
            statusMessage = "Cartella '\(url.lastPathComponent)' collegata con successo!"
        } catch {
            statusMessage = "Errore salvataggio cartella: \(error.localizedDescription)"
        }
    }
    
    @discardableResult
    func exportHealthDataToICloud(daysCount: Int = 14) async -> Bool {
        await MainActor.run {
            self.isSyncing = true
            self.statusMessage = "Estrazione dati Apple Health in corso..."
        }
        
        // 1. Estrai lo storico da HealthKit
        let history = await HealthKitManager.shared.fetchRecentHistory(daysCount: daysCount)
        guard !history.isEmpty else {
            await MainActor.run {
                self.isSyncing = false
                self.statusMessage = "Nessun dato HealthKit disponibile."
            }
            return false
        }
        
        // 2. Costruisci il dizionario compatibile sia con tracker.py che con import_apple_health.py
        var daysDict: [String: [String: Any]] = [:]
        for item in history {
            daysDict[item.date] = [
                "steps": item.steps,
                "passi": item.steps,
                "active_kcal": item.activeKcal,
                "calorie_attive": item.activeKcal,
                "resting_kcal": item.restingKcal,
                "calorie_riposo": item.restingKcal
            ]
        }
        
        let payload: [String: Any] = [
            "updated_at": ISO8601DateFormatter().string(from: Date()),
            "device": "iPhone & Apple Watch (MacroBara App)",
            "days_count": history.count,
            "days": daysDict
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]) else {
            await MainActor.run {
                self.isSyncing = false
                self.statusMessage = "Errore serializzazione JSON."
            }
            return false
        }
        
        var exportedSuccessfully = false
        
        // 3. Salvataggio su iCloud Drive (tramite Security-Scoped Bookmark)
        if let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) {
            var isStale = false
            if let folderURL = try? URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale) {
                if folderURL.startAccessingSecurityScopedResource() {
                    defer { folderURL.stopAccessingSecurityScopedResource() }
                    
                    let targetURL = folderURL.appendingPathComponent("health_sync.json")
                    do {
                        try jsonData.write(to: targetURL, options: .atomic)
                        exportedSuccessfully = true
                        
                        // Per massima compatibilità con la scorciatoia esistente, salviamo anche Automazione.txt per oggi
                        if let todayItem = history.first {
                            let singleDayDict: [String: Any] = [
                                "data": todayItem.date,
                                "passi": todayItem.steps,
                                "calorie_attive": todayItem.activeKcal
                            ]
                            if let singleData = try? JSONSerialization.data(withJSONObject: singleDayDict, options: .prettyPrinted) {
                                let singleURL = folderURL.appendingPathComponent("Automazione.txt")
                                try? singleData.write(to: singleURL, options: .atomic)
                            }
                        }
                    } catch {
                        print("Errore scrittura su iCloud: \(error.localizedDescription)")
                    }
                }
            }
        }
        
        // 4. Salva sempre anche nella directory Documents locale dell'app come copia di backup
        if let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let localURL = docsURL.appendingPathComponent("health_sync.json")
            try? jsonData.write(to: localURL, options: .atomic)
            if !exportedSuccessfully {
                exportedSuccessfully = true
            }
        }
        
        let now = Date()
        await MainActor.run {
            self.lastSyncDate = now
            self.isSyncing = false
            if self.isFolderLinked {
                self.statusMessage = "✅ Sincronizzati \(history.count) giorni su iCloud Drive (\(self.configuredFolderName ?? "Automazione"))!"
            } else {
                self.statusMessage = "Salvato in documenti locali (collega la cartella iCloud per sincronizzare con l'Assistente)."
            }
        }
        
        return exportedSuccessfully
    }
}
