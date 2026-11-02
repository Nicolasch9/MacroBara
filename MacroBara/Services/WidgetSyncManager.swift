//
//  WidgetSyncManager.swift
//  MacroBara
//

import Foundation
import WidgetKit
import SwiftUI

final class WidgetSyncManager {
    static let shared = WidgetSyncManager()
    
    static let appGroupSuiteNames = [
        "group.com.macrobara.app",
        "group.macrobara"
    ]
    
    static let widgetDataKey = "macrobara_widget_data_v1"
    
    func syncWidget(todayLog: DailyLog?, profile: UserProfile?, allLogs: [DailyLog]) {
        let p = profile ?? UserProfile()
        let targetKcal = Int(p.targetKcal > 0 ? p.targetKcal : 1600)
        let targetProtein = p.targetProteinG > 0 ? p.targetProteinG : 130.0
        let targetSugars = p.targetSugarMaxG > 0 ? p.targetSugarMaxG : 40.0
        let targetSteps = 7500
        
        let todayKcal = Int(todayLog?.totalKcal ?? 0)
        let kcalRemaining = max(0, targetKcal - todayKcal)
        let percentTarget = targetKcal > 0 ? Int((Double(todayKcal) / Double(targetKcal)) * 100) : 0
        
        let bmr = p.bmrKcal > 0 ? p.bmrKcal : 1750.0
        let activeKcal = (todayLog?.activeKcal ?? 0) > 0 ? (todayLog?.activeKcal ?? 400.0) : 400.0
        let tdee = max(2150.0, bmr + activeKcal)
        let targetDeficit = max(0.0, p.defaultTdeeKcal - p.targetKcal)
        let todayDeficit = Int(todayKcal > 0 ? (Double(todayKcal) - tdee) : -targetDeficit)
        
        let proteinG = todayLog?.totalProtein ?? 0.0
        let sugarsG = todayLog?.totalSugars ?? 0.0
        let steps = todayLog?.steps ?? 0
        
        let calendar = Calendar.current
        let today = Date()
        let todayStr = DailyLog.dateFormatter.string(from: today)
        var logsMap: [String: DailyLog] = [:]
        for l in allLogs {
            if let existing = logsMap[l.dateString] {
                if l.meals.count > existing.meals.count {
                    logsMap[l.dateString] = l
                }
            } else {
                logsMap[l.dateString] = l
            }
        }
        
        var dayItems: [[String: Any]] = []
        let dayInitials = ["L", "M", "M", "G", "V", "S", "D"]
        let dayNames = ["Lun", "Mar", "Mer", "Gio", "Ven", "Sab", "Dom"]
        
        // Calcola il lunedì della settimana corrente (settimana ISO)
        let weekday = (calendar.component(.weekday, from: today) + 5) % 7 // 0 = Lun, ..., 6 = Dom
        let monday = calendar.date(byAdding: .day, value: -weekday, to: calendar.startOfDay(for: today)) ?? today
        
        var totalDeficitSum: Double = 0.0
        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: i, to: monday) else { continue }
            let dStr = DailyLog.dateFormatter.string(from: date)
            let isDayToday = (dStr == todayStr)
            let initial = dayInitials[i]
            let name = dayNames[i]
            
            if isDayToday && todayLog != nil && !todayLog!.meals.isEmpty {
                let gradeResult = NutritionEngine.shared.calculateGrade(for: todayLog!, profile: p)
                dayItems.append([
                    "date": dStr,
                    "day_initial": initial,
                    "day_name": name,
                    "is_today": true,
                    "is_logged": true,
                    "kcal": todayLog!.totalKcal,
                    "deficit": Double(todayDeficit),
                    "grade": gradeResult.grade,
                    "score": gradeResult.score,
                    "sugars": todayLog!.totalSugars,
                    "protein": todayLog!.totalProtein,
                    "steps": steps
                ])
                totalDeficitSum += Double(todayDeficit)
            } else if let log = logsMap[dStr], !log.meals.isEmpty {
                let gradeResult = NutritionEngine.shared.calculateGrade(for: log, profile: p)
                let logBmr = (log.restingKcal >= 1500.0 && log.restingKcal <= 1850.0) ? log.restingKcal : 1750.0
                let logActive = log.activeKcal > 0 ? log.activeKcal : 400.0
                let logTdee = max(2150.0, logBmr + logActive)
                let logDeficit = log.totalKcal - logTdee
                dayItems.append([
                    "date": dStr,
                    "day_initial": initial,
                    "day_name": name,
                    "is_today": isDayToday,
                    "is_logged": true,
                    "kcal": log.totalKcal,
                    "deficit": logDeficit,
                    "grade": gradeResult.grade,
                    "score": gradeResult.score,
                    "sugars": log.totalSugars,
                    "protein": log.totalProtein,
                    "steps": log.steps
                ])
                totalDeficitSum += logDeficit
            } else {
                dayItems.append([
                    "date": dStr,
                    "day_initial": initial,
                    "day_name": name,
                    "is_today": isDayToday,
                    "is_logged": false,
                    "kcal": 0,
                    "deficit": 0,
                    "grade": "-",
                    "score": 0,
                    "sugars": 0.0,
                    "protein": 0.0,
                    "steps": 0
                ])
            }
        }
        
        let estFatLoss = max(0, -totalDeficitSum / 7700.0)
        
        // Payload dizionario conforme alle specifiche del Widget
        let payload: [String: Any] = [
            "target_kcal": targetKcal,
            "target_protein": targetProtein,
            "target_sugars": targetSugars,
            "target_steps": targetSteps,
            "total_deficit": totalDeficitSum,
            "est_fat_loss_kg": (estFatLoss * 100).rounded() / 100,
            "week_grade": "A+",
            "today": [
                "date": todayStr,
                "weekday": DailyLog.weekdayFormatter.string(from: today).capitalized,
                "grade": todayLog != nil && !todayLog!.meals.isEmpty ? NutritionEngine.shared.calculateGrade(for: todayLog!, profile: p).grade : "A",
                "kcal": Double(todayKcal),
                "kcal_remaining": kcalRemaining,
                "percent_target": percentTarget,
                "deficit": Double(todayDeficit),
                "sugars": sugarsG,
                "protein": proteinG,
                "steps": steps
            ],
            "days": dayItems
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: []) {
            // 1. Scrivi su tutti i possibili App Groups
            for suite in Self.appGroupSuiteNames {
                if let defaults = UserDefaults(suiteName: suite) {
                    defaults.set(data, forKey: Self.widgetDataKey)
                }
                if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suite) {
                    let fileURL = container.appendingPathComponent("widget_data.json")
                    try? data.write(to: fileURL)
                }
            }
            
            // 2. Salva in standard UserDefaults come fallback
            UserDefaults.standard.set(data, forKey: Self.widgetDataKey)
        }
        
        // 3. Notifica a WidgetKit di ricaricare immediatamente tutti i widget sulla schermata Home
        WidgetCenter.shared.reloadAllTimelines()
        print("🦫 WidgetSyncManager: sincronizzazione widget completata! Oggi: \(todayKcal) kcal (\(percentTarget)%), \(kcalRemaining) kcal rimaste, \(Int(proteinG))g Pro, deficit \(todayDeficit) kcal.")
    }
}
