//
//  DataImporter.swift
//  MacroBara
//

import Foundation
import SwiftData

final class DataImporter {
    static let shared = DataImporter()
    
    func consolidateAndDeduplicate(modelContext: ModelContext) {
        let logDescriptor = FetchDescriptor<DailyLog>()
        guard let allLogs = try? modelContext.fetch(logDescriptor), !allLogs.isEmpty else { return }
        
        var logsByDate: [String: [DailyLog]] = [:]
        for log in allLogs {
            logsByDate[log.dateString, default: []].append(log)
        }
        
        var didModify = false
        for (_, group) in logsByDate {
            if group.count > 1 {
                didModify = true
                // Scegli il log canonico: quello con più pasti o calorie attive
                let canonical = group.max(by: {
                    if $0.meals.count != $1.meals.count {
                        return $0.meals.count < $1.meals.count
                    }
                    return $0.activeKcal < $1.activeKcal
                }) ?? group[0]
                
                for duplicate in group where duplicate.id != canonical.id {
                    for meal in duplicate.meals {
                        if !canonical.meals.contains(where: { $0.title == meal.title && $0.kcal == meal.kcal }) {
                            meal.dailyLog = canonical
                            canonical.meals.append(meal)
                        } else {
                            modelContext.delete(meal)
                        }
                    }
                    canonical.steps = max(canonical.steps, duplicate.steps)
                    canonical.activeKcal = max(canonical.activeKcal, duplicate.activeKcal)
                    if canonical.restingKcal == 0 { canonical.restingKcal = duplicate.restingKcal }
                    if canonical.waterL == 0 { canonical.waterL = duplicate.waterL }
                    if canonical.dailyNotes.isEmpty { canonical.dailyNotes = duplicate.dailyNotes }
                    
                    modelContext.delete(duplicate)
                }
            }
        }
        
        // Sanifica e assicura che il metabolismo basale (BMR) sia rigorosamente 1750 kcal
        for l in allLogs {
            if l.restingKcal != 1750.0 {
                l.restingKcal = 1750.0
                didModify = true
            }
        }
        
        if didModify {
            try? modelContext.save()
            print("✅ Consolidamento duplicati completato: memoria SwiftData unificata con successo!")
        }
    }
    
    func importHistoryIfNeeded(modelContext: ModelContext, force: Bool = false) {
        consolidateAndDeduplicate(modelContext: modelContext)
        
        let data: Data
        if let url = Bundle.main.url(forResource: "initial_history", withExtension: "json") ??
                     Bundle.main.url(forResource: "initial_history", withExtension: "json", subdirectory: "Resources"),
           let fileData = try? Data(contentsOf: url) {
            data = fileData
        } else {
            data = Data(DataImporter.embeddedHistoryJSON.utf8)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let daysDict = json["days"] as? [String: [String: Any]] else {
            return
        }
        
        let logDescriptor = FetchDescriptor<DailyLog>()
        let existingLogs = (try? modelContext.fetch(logDescriptor)) ?? []
        var existingMap: [String: DailyLog] = [:]
        for l in existingLogs {
            if let existing = existingMap[l.dateString] {
                if l.meals.count > existing.meals.count {
                    existingMap[l.dateString] = l
                }
            } else {
                existingMap[l.dateString] = l
            }
        }
        
        let weighDescriptor = FetchDescriptor<WeighIn>()
        let weighCount = (try? modelContext.fetchCount(weighDescriptor)) ?? 0
        
        var needsUpdate = force || existingLogs.isEmpty || weighCount == 0
        if !needsUpdate {
            for (dateStr, dayData) in daysDict {
                if let existing = existingMap[dateStr] {
                    let jsonMeals = (dayData["meals"] as? [[String: Any]]) ?? []
                    if jsonMeals.count > existing.meals.count {
                        needsUpdate = true
                        break
                    }
                } else {
                    needsUpdate = true
                    break
                }
            }
        }
        
        if needsUpdate {
            cleanupAndImport(modelContext: modelContext, customData: data)
        }
    }
    
    func cleanupAndImport(modelContext: ModelContext, customData: Data? = nil) {
        do {
            let data: Data
            if let customData = customData {
                data = customData
            } else if let url = Bundle.main.url(forResource: "initial_history", withExtension: "json") ??
                                Bundle.main.url(forResource: "initial_history", withExtension: "json", subdirectory: "Resources"),
                      let fileData = try? Data(contentsOf: url) {
                data = fileData
            } else {
                data = Data(DataImporter.embeddedHistoryJSON.utf8)
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            
            // 1. Profilo
            if let profileDict = json["profile"] as? [String: Any] {
                let profileDescriptor = FetchDescriptor<UserProfile>()
                if let existingProfiles = try? modelContext.fetch(profileDescriptor), let p = existingProfiles.first {
                    p.currentWeightKg = (profileDict["current_weight_kg"] as? Double) ?? p.currentWeightKg
                    p.targetWeightKg = (profileDict["target_weight_kg"] as? Double) ?? p.targetWeightKg
                    p.normopesoMaxWeightKg = (profileDict["normopeso_max_weight_kg"] as? Double) ?? p.normopesoMaxWeightKg
                    p.startWeightKg = (profileDict["start_weight_kg"] as? Double) ?? 89.0
                    p.bmrKcal = (profileDict["bmr"] as? Double) ?? p.bmrKcal
                    p.defaultTdeeKcal = (profileDict["tdee_kcal"] as? Double) ?? p.defaultTdeeKcal
                    p.targetKcal = (profileDict["target_calories"] as? Double) ?? p.targetKcal
                }
            }
            
            // 2. DEDUP & AGGIORNAMENTO PESATE SETTIMANALI
            let weighInDescriptor = FetchDescriptor<WeighIn>()
            let existingWeighIns = (try? modelContext.fetch(weighInDescriptor)) ?? []
            for w in existingWeighIns {
                modelContext.delete(w)
            }
            
            if let weighInsArray = json["weigh_ins"] as? [[String: Any]] {
                var insertedWeeks = Set<Int>()
                for item in weighInsArray {
                    let week = (item["week_number"] as? Int) ?? 0
                    if !insertedWeeks.contains(week) {
                        insertedWeeks.insert(week)
                        let dateStr = (item["date"] as? String) ?? ""
                        let date = DailyLog.dateFormatter.date(from: dateStr) ?? Date()
                        let weight = (item["weight_kg"] as? Double) ?? 89.0
                        let deltaPrev = (item["delta_prev_kg"] as? Double) ?? 0.0
                        let deltaTotal = (item["delta_total_kg"] as? Double) ?? 0.0
                        let notes = (item["notes"] as? String) ?? ""
                        
                        let w = WeighIn(
                            weekNumber: week,
                            date: date,
                            weightKg: weight,
                            deltaPrevKg: deltaPrev,
                            deltaTotalKg: deltaTotal,
                            notes: notes
                        )
                        modelContext.insert(w)
                    }
                }
            }
            
            // 3. DEDUP & IMPORTAZIONE GIORNI E PASTI REALI
            let logDescriptor = FetchDescriptor<DailyLog>()
            let existingLogs = (try? modelContext.fetch(logDescriptor)) ?? []
            var logByDate: [String: DailyLog] = [:]
            
            for l in existingLogs {
                if let existing = logByDate[l.dateString] {
                    // Se abbiamo un duplicato, eliminiamo il duplicato vuoto
                    if existing.meals.isEmpty && !l.meals.isEmpty {
                        modelContext.delete(existing)
                        logByDate[l.dateString] = l
                    } else {
                        modelContext.delete(l)
                    }
                } else {
                    logByDate[l.dateString] = l
                }
            }
            
            if let daysDict = json["days"] as? [String: [String: Any]] {
                for (dateStr, dayData) in daysDict {
                    let date = DailyLog.dateFormatter.date(from: dateStr) ?? Date()
                    let weekday = (dayData["weekday"] as? String) ?? ""
                    let dailyNotes = (dayData["daily_notes"] as? String) ?? ""
                    let steps = (dayData["steps"] as? Int) ?? 0
                    var activeKcal = (dayData["active_kcal"] as? Double) ?? 0.0
                    let restingKcal = (dayData["resting_kcal"] as? Double) ?? 1750.0
                    let realTdee = (dayData["real_tdee"] as? Double) ?? 0.0
                    let waterL = (dayData["total_water_l"] as? Double) ?? 0.0
                    
                    if activeKcal == 0 && realTdee > restingKcal {
                        activeKcal = realTdee - restingKcal
                    } else if activeKcal == 0 && realTdee == 0 {
                        activeKcal = 400.0
                    }
                    
                    let log: DailyLog
                    if let existingLog = logByDate[dateStr] {
                        log = existingLog
                        log.date = date
                        log.weekday = weekday
                        log.dailyNotes = dailyNotes
                        if steps > 0 || log.steps == 0 { log.steps = steps }
                        if activeKcal > 0 || log.activeKcal == 0 { log.activeKcal = activeKcal }
                        if restingKcal > 0 || log.restingKcal == 0 { log.restingKcal = restingKcal }
                        if waterL > 0 || log.waterL == 0 { log.waterL = waterL }
                        
                        // Rimuovi pasti vecchi duplicati
                        for oldMeal in log.meals {
                            modelContext.delete(oldMeal)
                        }
                        log.meals.removeAll()
                    } else {
                        log = DailyLog(
                            date: date,
                            dateString: dateStr,
                            weekday: weekday,
                            dailyNotes: dailyNotes,
                            steps: steps,
                            activeKcal: activeKcal,
                            restingKcal: restingKcal,
                            waterL: waterL
                        )
                        modelContext.insert(log)
                        logByDate[dateStr] = log
                    }
                    
                    if let mealsArray = dayData["meals"] as? [[String: Any]] {
                        for (index, mealDict) in mealsArray.enumerated() {
                            let typeRaw = (mealDict["type"] as? String) ?? "Colazione"
                            let mealType = MealType(rawValue: typeRaw) ?? (typeRaw.lowercased().contains("spuntino") ? .spuntino : .colazione)
                            let desc = (mealDict["description"] as? String) ?? ""
                            let kcal = (mealDict["kcal"] as? Double) ?? 0.0
                            let protein = (mealDict["protein_g"] as? Double) ?? 0.0
                            let carbs = (mealDict["carbs_g"] as? Double) ?? 0.0
                            let fat = (mealDict["fat_g"] as? Double) ?? 0.0
                            let sugars = (mealDict["sugars_g"] as? Double) ?? 0.0
                            let notes = (mealDict["notes"] as? String) ?? ""
                            let water = (mealDict["water_l"] as? Double) ?? 0.0
                            
                            // Assegna orario fisiologico in base all'ordine e al tipo di pasto
                            let mealHour: Int
                            let mealMinute: Int
                            let lower = typeRaw.lowercased()
                            if lower.contains("colazione") {
                                mealHour = 8; mealMinute = 0
                            } else if lower.contains("pranzo") {
                                mealHour = 13; mealMinute = 0
                            } else if lower.contains("cena") {
                                mealHour = 20; mealMinute = 30
                            } else if lower.contains("spuntino") || lower.contains("snack") {
                                let hasPranzoBefore = mealsArray.prefix(index).contains(where: { (($0["type"] as? String) ?? "").lowercased().contains("pranzo") })
                                let hasCenaBefore = mealsArray.prefix(index).contains(where: { (($0["type"] as? String) ?? "").lowercased().contains("cena") })
                                if !hasPranzoBefore {
                                    mealHour = 10; mealMinute = 30 // Spuntino Mattina
                                } else if hasCenaBefore {
                                    mealHour = 22; mealMinute = 0 // Spuntino Sera
                                } else {
                                    mealHour = 17; mealMinute = 0 // Spuntino Pomeriggio
                                }
                            } else {
                                mealHour = 12; mealMinute = index * 10
                            }
                            
                            let mealDate = Calendar.current.date(bySettingHour: mealHour, minute: mealMinute, second: 0, of: date) ?? date
                            
                            let entry = MealEntry(
                                date: mealDate,
                                mealType: mealType,
                                mealTypeRaw: typeRaw,
                                title: typeRaw,
                                foodDescription: desc,
                                kcal: kcal,
                                proteinG: protein,
                                carbsG: carbs,
                                fatG: fat,
                                sugarsG: sugars,
                                waterL: water,
                                notes: notes
                            )
                            entry.dailyLog = log
                            log.meals.append(entry)
                            modelContext.insert(entry)
                        }
                    }
                }
            }
            
            try? modelContext.save()
            print("✅ Deduplicazione e importazione completata con successo!")
            
            let todayStr = DailyLog.dateFormatter.string(from: Date())
            let logDesc = FetchDescriptor<DailyLog>()
            let allLogs = (try? modelContext.fetch(logDesc)) ?? []
            let todayLog = allLogs.first(where: { $0.dateString == todayStr })
            let profileDesc = FetchDescriptor<UserProfile>()
            let profile = (try? modelContext.fetch(profileDesc))?.first
            WidgetSyncManager.shared.syncWidget(todayLog: todayLog, profile: profile, allLogs: allLogs)
        } catch {
            print("Errore cleanupAndImport: \(error.localizedDescription)")
        }
    }
    
    static let embeddedHistoryJSON: String = #"""
{
  "profile": {
    "name": "Demo User",
    "age": 28,
    "occupation": "Software Engineer & Fitness Enthusiast",
    "height_cm": 180,
    "start_weight_kg": 88.0,
    "current_weight_kg": 86.8,
    "target_weight_kg": 78.0,
    "normopeso_max_weight_kg": 80.7,
    "weight_to_normopeso_kg": 6.1,
    "tdee_kcal": 2150.0,
    "target_kcal_min": 1500,
    "target_kcal_max": 1700,
    "target_kcal_avg": 1600,
    "target_deficit_daily_kcal": 550,
    "target_protein_g": 130,
    "target_carbs_g": 170,
    "target_fat_g": 50,
    "target_sugar_max_g": 40,
    "target_water_l": 2.5,
    "start_date": "2026-10-19",
    "prev_week_sugary_drinks": 0,
    "bmr": 1750.0,
    "target_calories": 1600
  },
  "meal_presets": {
    "porridge_bowl": {
      "name": "Porridge Proteico Avena & Frutti di Bosco",
      "type": "Colazione",
      "description": "Porridge d'avena con proteine isolate, semi di chia, mirtilli e latte vegetale (45g avena, 20g whey, 10g chia, 150ml latte mandorla)",
      "kcal": 405.0,
      "protein_g": 27.5,
      "carbs_g": 41.0,
      "fat_g": 11.5,
      "sugars_g": 7.5,
      "water_l": 0.4,
      "notes": "Preset demo per colazione standard bilanciata"
    },
    "yogurt_bowl": {
      "name": "Bowl Yogurt Greco & Frutta Secca",
      "type": "Colazione",
      "description": "Yogurt greco magro 0% con granola integrale e noci (150g yogurt greco, 30g granola, 10g noci)",
      "kcal": 310.0,
      "protein_g": 22.0,
      "carbs_g": 28.0,
      "fat_g": 9.5,
      "sugars_g": 6.0,
      "water_l": 0.3,
      "notes": "Preset demo per colazione rapida o spuntino"
    }
  },
  "weigh_ins": [
    {
      "week_number": 0,
      "date": "2026-10-19",
      "weight_kg": 88.0,
      "delta_prev_kg": 0.0,
      "delta_total_kg": 0.0,
      "avg_kcal": null,
      "notes": "Inizio percorso dimostrativo (Settimana 0)"
    },
    {
      "week_number": 1,
      "date": "2026-10-25",
      "weight_kg": 87.4,
      "delta_prev_kg": -0.6,
      "delta_total_kg": -0.6,
      "avg_kcal": 1610.0,
      "notes": "Pesata di controllo fine Settimana 1 (-0.6 kg)"
    },
    {
      "week_number": 2,
      "date": "2026-11-01",
      "weight_kg": 86.8,
      "delta_prev_kg": -0.6,
      "delta_total_kg": -1.2,
      "avg_kcal": 1595.0,
      "notes": "Pesata di controllo fine Settimana 2 (-1.2 kg totali)"
    }
  ],
  "days": {
    "2026-10-19": {
      "date": "2026-10-19",
      "weekday": "Lunedì",
      "meals": [
        {
          "type": "Colazione",
          "description": "Porridge proteico d'avena con mirtilli freschi e semi di chia (45g avena, 20g whey, 10g chia, 150ml latte vegetale)",
          "kcal": 405.0,
          "protein_g": 27.5,
          "carbs_g": 41.0,
          "fat_g": 11.5,
          "sugars_g": 7.5,
          "water_l": 0.4,
          "notes": "Colazione ricca di fibre solubili e proteine a lento rilascio",
          "id": 1
        },
        {
          "type": "Pranzo",
          "description": "Riso basmati integrale con petto di pollo alle erbe e zucchine trifolate (70g riso, 180g pollo, 150g zucchine, 10g evo)",
          "kcal": 525.0,
          "protein_g": 43.0,
          "carbs_g": 56.0,
          "fat_g": 11.5,
          "sugars_g": 4.0,
          "water_l": 0.6,
          "notes": "Pranzo classico bilanciato ad alta digeribilità",
          "id": 2
        },
        {
          "type": "Spuntino",
          "description": "Yogurt greco magro con gherigli di noce (150g yogurt greco 0%, 15g noci)",
          "kcal": 185.0,
          "protein_g": 16.5,
          "carbs_g": 6.5,
          "fat_g": 9.5,
          "sugars_g": 5.0,
          "water_l": 0.3,
          "notes": "Snack pomeridiano spezza-fame ricco di grassi buoni",
          "id": 3
        },
        {
          "type": "Cena",
          "description": "Filetto di orata al cartoccio con patate novelle al rosmarino e fagiolini (180g orata, 150g patate, 150g fagiolini, 8g evo)",
          "kcal": 475.0,
          "protein_g": 42.0,
          "carbs_g": 43.0,
          "fat_g": 10.0,
          "sugars_g": 4.5,
          "water_l": 0.8,
          "notes": "Cena leggera ad altissima digeribilità ideale per il sonno",
          "id": 4
        }
      ],
      "total_kcal": 1590.0,
      "total_protein": 129.0,
      "total_carbs": 146.5,
      "total_fat": 42.5,
      "total_sugars": 21.0,
      "total_water_l": 2.1,
      "daily_notes": "Lunedì demo: 1590.0 kcal (target 1600 centrato), 129.0g pro e 42.5g grassi. Giornata perfettamente bilanciata: introito calorico in target e zuccheri semplici contenuti.",
      "steps": 0,
      "active_kcal": 400.0,
      "resting_kcal": 1750.0,
      "real_tdee": 2150.0
    },
    "2026-10-20": {
      "date": "2026-10-20",
      "weekday": "Martedì",
      "meals": [
        {
          "type": "Colazione",
          "description": "Pancake d'avena e albume con yogurt greco 0% e frutti di bosco (40g farina d'avena, 120g albume, 50g yogurt greco)",
          "kcal": 385.0,
          "protein_g": 28.0,
          "carbs_g": 38.5,
          "fat_g": 8.0,
          "sugars_g": 6.0,
          "water_l": 0.4,
          "notes": "Pancake soffici ad alto valore biologico",
          "id": 1
        },
        {
          "type": "Pranzo",
          "description": "Pasta integrale con trancio di salmone, pomodorini datterini e rucola (75g pasta, 100g salmone, 100g pomodorini, 5g evo)",
          "kcal": 535.0,
          "protein_g": 37.0,
          "carbs_g": 59.0,
          "fat_g": 13.5,
          "sugars_g": 4.5,
          "water_l": 0.6,
          "notes": "Fonte eccellente di Omega-3 e carboidrati complessi",
          "id": 2
        },
        {
          "type": "Spuntino",
          "description": "Mela fresca a fette con burro d'arachidi 100% puro (150g mela, 15g burro arachidi)",
          "kcal": 175.0,
          "protein_g": 4.5,
          "carbs_g": 22.0,
          "fat_g": 7.5,
          "sugars_g": 14.0,
          "water_l": 0.3,
          "notes": "Energia pronta con fibre e micronutrienti",
          "id": 3
        },
        {
          "type": "Cena",
          "description": "Tagliata di manzo magro con rucola selvatica, pomodorini e pane di segale (160g manzo, 10g grana, rucola, 50g pane segale, 5g evo)",
          "kcal": 485.0,
          "protein_g": 44.0,
          "carbs_g": 36.0,
          "fat_g": 14.0,
          "sugars_g": 3.0,
          "water_l": 0.8,
          "notes": "Apporto di ferro biodisponibile e proteine nobili",
          "id": 4
        }
      ],
      "total_kcal": 1580.0,
      "total_protein": 113.5,
      "total_carbs": 155.5,
      "total_fat": 43.0,
      "total_sugars": 27.5,
      "total_water_l": 2.1,
      "daily_notes": "Martedì demo: 1580.0 kcal (target 1600 centrato), 113.5g pro e 43.0g grassi. Ottima aderenza nutrizionale: proteine elevate a supporto della massa magra e idratazione corretta.",
      "steps": 0,
      "active_kcal": 400.0,
      "resting_kcal": 1750.0,
      "real_tdee": 2150.0
    },
    "2026-10-21": {
      "date": "2026-10-21",
      "weekday": "Mercoledì",
      "meals": [
        {
          "type": "Colazione",
          "description": "Toast di pane integrale con uova in camicia e fettine di avocado (60g pane integrale, 2 uova, 30g avocado)",
          "kcal": 415.0,
          "protein_g": 23.5,
          "carbs_g": 32.0,
          "fat_g": 17.5,
          "sugars_g": 3.0,
          "water_l": 0.4,
          "notes": "Colazione bilanciata con grassi monoinsaturi e proteine nobili",
          "id": 1
        },
        {
          "type": "Pranzo",
          "description": "Quinoa con fesa di tacchino ai ferri, peperoni grigliati e mandorle (70g quinoa, 170g tacchino, 100g peperoni, 10g mandorle)",
          "kcal": 505.0,
          "protein_g": 42.5,
          "carbs_g": 49.0,
          "fat_g": 12.0,
          "sugars_g": 4.2,
          "water_l": 0.6,
          "notes": "Profilo aminoacidico completo e ricco di minerali",
          "id": 2
        },
        {
          "type": "Spuntino",
          "description": "Toast croccante di segale con fesa di tacchino e formaggio light (40g pane segale, 60g tacchino, 20g formaggio magro)",
          "kcal": 180.0,
          "protein_g": 18.0,
          "carbs_g": 17.0,
          "fat_g": 3.5,
          "sugars_g": 2.0,
          "water_l": 0.3,
          "notes": "Spuntino salato ad altissimo contenuto proteico",
          "id": 3
        },
        {
          "type": "Cena",
          "description": "Trancio di merluzzo con crema di zucca al forno e crostini integrali (200g merluzzo, 200g zucca, 40g crostini integrali, 8g evo)",
          "kcal": 460.0,
          "protein_g": 41.5,
          "carbs_g": 42.0,
          "fat_g": 9.5,
          "sugars_g": 6.5,
          "water_l": 0.8,
          "notes": "Volume saziante ad elevata densità di micronutrienti",
          "id": 4
        }
      ],
      "total_kcal": 1560.0,
      "total_protein": 125.5,
      "total_carbs": 140.0,
      "total_fat": 42.5,
      "total_sugars": 15.7,
      "total_water_l": 2.1,
      "daily_notes": "Mercoledì demo: 1560.0 kcal (target 1600 centrato), 125.5g pro e 42.5g grassi. Alimentazione pulita e saziante: pasti a densità nutrizionale elevata e glicemia stabile.",
      "steps": 0,
      "active_kcal": 400.0,
      "resting_kcal": 1750.0,
      "real_tdee": 2150.0
    },
    "2026-10-22": {
      "date": "2026-10-22",
      "weekday": "Giovedì",
      "meals": [
        {
          "type": "Colazione",
          "description": "Yogurt bowl con yogurt greco magro, granola d'avena integrale e banana (150g yogurt greco 0%, 30g granola, 60g banana)",
          "kcal": 395.0,
          "protein_g": 26.0,
          "carbs_g": 46.0,
          "fat_g": 7.5,
          "sugars_g": 11.0,
          "water_l": 0.4,
          "notes": "Bowl fresca e saziante con probiotici e micronutrienti",
          "id": 1
        },
        {
          "type": "Pranzo",
          "description": "Poke bowl con riso venere, tartare di tonno al naturale, edamame e cetrioli (70g riso venere, 120g tonno, 50g edamame, cetriolo, 5g evo)",
          "kcal": 515.0,
          "protein_g": 41.0,
          "carbs_g": 53.0,
          "fat_g": 11.0,
          "sugars_g": 3.8,
          "water_l": 0.6,
          "notes": "Pranzo fresco a basso indice glicemico",
          "id": 2
        },
        {
          "type": "Spuntino",
          "description": "Smoothie proteico con mirtilli, latte di soia e whey isolate (150ml latte soia, 15g whey, 50g mirtilli)",
          "kcal": 170.0,
          "protein_g": 19.0,
          "carbs_g": 13.0,
          "fat_g": 3.0,
          "sugars_g": 7.0,
          "water_l": 0.3,
          "notes": "Idratazione e recupero muscolare",
          "id": 3
        },
        {
          "type": "Cena",
          "description": "Omelette con 1 uovo e 150g albume, spinaci freschi saltati e pane ai cereali (1 uovo, 150g albume, spinaci, 50g pane cereali, 5g evo)",
          "kcal": 445.0,
          "protein_g": 35.0,
          "carbs_g": 35.0,
          "fat_g": 13.0,
          "sugars_g": 3.5,
          "water_l": 0.8,
          "notes": "Cena essenziale e bilanciata a rapido assorbimento",
          "id": 4
        }
      ],
      "total_kcal": 1525.0,
      "total_protein": 121.0,
      "total_carbs": 147.0,
      "total_fat": 34.5,
      "total_sugars": 25.3,
      "total_water_l": 2.1,
      "daily_notes": "Giovedì demo: 1525.0 kcal (target 1600 centrato), 121.0g pro e 34.5g grassi. Bilancio ideale: rispetto del deficit calorico moderato senza sensazione di fame o cali energetici.",
      "steps": 0,
      "active_kcal": 400.0,
      "resting_kcal": 1750.0,
      "real_tdee": 2150.0
    },
    "2026-10-23": {
      "date": "2026-10-23",
      "weekday": "Venerdì",
      "meals": [
        {
          "type": "Colazione",
          "description": "Porridge proteico d'avena con mirtilli freschi e semi di chia (45g avena, 20g whey, 10g chia, 150ml latte vegetale)",
          "kcal": 405.0,
          "protein_g": 27.5,
          "carbs_g": 41.0,
          "fat_g": 11.5,
          "sugars_g": 7.5,
          "water_l": 0.4,
          "notes": "Colazione ricca di fibre solubili e proteine a lento rilascio",
          "id": 1
        },
        {
          "type": "Pranzo",
          "description": "Riso basmati integrale con petto di pollo alle erbe e zucchine trifolate (70g riso, 180g pollo, 150g zucchine, 10g evo)",
          "kcal": 525.0,
          "protein_g": 43.0,
          "carbs_g": 56.0,
          "fat_g": 11.5,
          "sugars_g": 4.0,
          "water_l": 0.6,
          "notes": "Pranzo classico bilanciato ad alta digeribilità",
          "id": 2
        },
        {
          "type": "Spuntino",
          "description": "Yogurt greco magro con gherigli di noce (150g yogurt greco 0%, 15g noci)",
          "kcal": 185.0,
          "protein_g": 16.5,
          "carbs_g": 6.5,
          "fat_g": 9.5,
          "sugars_g": 5.0,
          "water_l": 0.3,
          "notes": "Snack pomeridiano spezza-fame ricco di grassi buoni",
          "id": 3
        },
        {
          "type": "Cena",
          "description": "Filetto di orata al cartoccio con patate novelle al rosmarino e fagiolini (180g orata, 150g patate, 150g fagiolini, 8g evo)",
          "kcal": 475.0,
          "protein_g": 42.0,
          "carbs_g": 43.0,
          "fat_g": 10.0,
          "sugars_g": 4.5,
          "water_l": 0.8,
          "notes": "Cena leggera ad altissima digeribilità ideale per il sonno",
          "id": 4
        }
      ],
      "total_kcal": 1590.0,
      "total_protein": 129.0,
      "total_carbs": 146.5,
      "total_fat": 42.5,
      "total_sugars": 21.0,
      "total_water_l": 2.1,
      "daily_notes": "Venerdì demo: 1590.0 kcal (target 1600 centrato), 129.0g pro e 42.5g grassi. Giornata perfettamente bilanciata: introito calorico in target e zuccheri semplici contenuti.",
      "steps": 0,
      "active_kcal": 400.0,
      "resting_kcal": 1750.0,
      "real_tdee": 2150.0
    },
    "2026-10-24": {
      "date": "2026-10-24",
      "weekday": "Sabato",
      "meals": [
        {
          "type": "Colazione",
          "description": "Pancake d'avena e albume con yogurt greco 0% e frutti di bosco (40g farina d'avena, 120g albume, 50g yogurt greco)",
          "kcal": 385.0,
          "protein_g": 28.0,
          "carbs_g": 38.5,
          "fat_g": 8.0,
          "sugars_g": 6.0,
          "water_l": 0.4,
          "notes": "Pancake soffici ad alto valore biologico",
          "id": 1
        },
        {
          "type": "Pranzo",
          "description": "Pasta integrale con trancio di salmone, pomodorini datterini e rucola (75g pasta, 100g salmone, 100g pomodorini, 5g evo)",
          "kcal": 535.0,
          "protein_g": 37.0,
          "carbs_g": 59.0,
          "fat_g": 13.5,
          "sugars_g": 4.5,
          "water_l": 0.6,
          "notes": "Fonte eccellente di Omega-3 e carboidrati complessi",
          "id": 2
        },
        {
          "type": "Spuntino",
          "description": "Mela fresca a fette con burro d'arachidi 100% puro (150g mela, 15g burro arachidi)",
          "kcal": 175.0,
          "protein_g": 4.5,
          "carbs_g": 22.0,
          "fat_g": 7.5,
          "sugars_g": 14.0,
          "water_l": 0.3,
          "notes": "Energia pronta con fibre e micronutrienti",
          "id": 3
        },
        {
          "type": "Cena",
          "description": "Tagliata di manzo magro con rucola selvatica, pomodorini e pane di segale (160g manzo, 10g grana, rucola, 50g pane segale, 5g evo)",
          "kcal": 485.0,
          "protein_g": 44.0,
          "carbs_g": 36.0,
          "fat_g": 14.0,
          "sugars_g": 3.0,
          "water_l": 0.8,
          "notes": "Apporto di ferro biodisponibile e proteine nobili",
          "id": 4
        }
      ],
      "total_kcal": 1580.0,
      "total_protein": 113.5,
      "total_carbs": 155.5,
      "total_fat": 43.0,
      "total_sugars": 27.5,
      "total_water_l": 2.1,
      "daily_notes": "Sabato demo: 1580.0 kcal (target 1600 centrato), 113.5g pro e 43.0g grassi. Ottima aderenza nutrizionale: proteine elevate a supporto della massa magra e idratazione corretta.",
      "steps": 0,
      "active_kcal": 400.0,
      "resting_kcal": 1750.0,
      "real_tdee": 2150.0
    },
    "2026-10-25": {
      "date": "2026-10-25",
      "weekday": "Domenica",
      "meals": [
        {
          "type": "Colazione",
          "description": "Toast di pane integrale con uova in camicia e fettine di avocado (60g pane integrale, 2 uova, 30g avocado)",
          "kcal": 415.0,
          "protein_g": 23.5,
          "carbs_g": 32.0,
          "fat_g": 17.5,
          "sugars_g": 3.0,
          "water_l": 0.4,
          "notes": "Colazione bilanciata con grassi monoinsaturi e proteine nobili",
          "id": 1
        },
        {
          "type": "Pranzo",
          "description": "Quinoa con fesa di tacchino ai ferri, peperoni grigliati e mandorle (70g quinoa, 170g tacchino, 100g peperoni, 10g mandorle)",
          "kcal": 505.0,
          "protein_g": 42.5,
          "carbs_g": 49.0,
          "fat_g": 12.0,
          "sugars_g": 4.2,
          "water_l": 0.6,
          "notes": "Profilo aminoacidico completo e ricco di minerali",
          "id": 2
        },
        {
          "type": "Spuntino",
          "description": "Toast croccante di segale con fesa di tacchino e formaggio light (40g pane segale, 60g tacchino, 20g formaggio magro)",
          "kcal": 180.0,
          "protein_g": 18.0,
          "carbs_g": 17.0,
          "fat_g": 3.5,
          "sugars_g": 2.0,
          "water_l": 0.3,
          "notes": "Spuntino salato ad altissimo contenuto proteico",
          "id": 3
        },
        {
          "type": "Cena",
          "description": "Trancio di merluzzo con crema di zucca al forno e crostini integrali (200g merluzzo, 200g zucca, 40g crostini integrali, 8g evo)",
          "kcal": 460.0,
          "protein_g": 41.5,
          "carbs_g": 42.0,
          "fat_g": 9.5,
          "sugars_g": 6.5,
          "water_l": 0.8,
          "notes": "Volume saziante ad elevata densità di micronutrienti",
          "id": 4
        }
      ],
      "total_kcal": 1560.0,
      "total_protein": 125.5,
      "total_carbs": 140.0,
      "total_fat": 42.5,
      "total_sugars": 15.7,
      "total_water_l": 2.1,
      "daily_notes": "Domenica demo: 1560.0 kcal (target 1600 centrato), 125.5g pro e 42.5g grassi. Alimentazione pulita e saziante: pasti a densità nutrizionale elevata e glicemia stabile.",
      "steps": 0,
      "active_kcal": 400.0,
      "resting_kcal": 1750.0,
      "real_tdee": 2150.0
    },
    "2026-10-26": {
      "date": "2026-10-26",
      "weekday": "Lunedì",
      "meals": [
        {
          "type": "Colazione",
          "description": "Yogurt bowl con yogurt greco magro, granola d'avena integrale e banana (150g yogurt greco 0%, 30g granola, 60g banana)",
          "kcal": 395.0,
          "protein_g": 26.0,
          "carbs_g": 46.0,
          "fat_g": 7.5,
          "sugars_g": 11.0,
          "water_l": 0.4,
          "notes": "Bowl fresca e saziante con probiotici e micronutrienti",
          "id": 1
        },
        {
          "type": "Pranzo",
          "description": "Poke bowl con riso venere, tartare di tonno al naturale, edamame e cetrioli (70g riso venere, 120g tonno, 50g edamame, cetriolo, 5g evo)",
          "kcal": 515.0,
          "protein_g": 41.0,
          "carbs_g": 53.0,
          "fat_g": 11.0,
          "sugars_g": 3.8,
          "water_l": 0.6,
          "notes": "Pranzo fresco a basso indice glicemico",
          "id": 2
        },
        {
          "type": "Spuntino",
          "description": "Smoothie proteico con mirtilli, latte di soia e whey isolate (150ml latte soia, 15g whey, 50g mirtilli)",
          "kcal": 170.0,
          "protein_g": 19.0,
          "carbs_g": 13.0,
          "fat_g": 3.0,
          "sugars_g": 7.0,
          "water_l": 0.3,
          "notes": "Idratazione e recupero muscolare",
          "id": 3
        },
        {
          "type": "Cena",
          "description": "Omelette con 1 uovo e 150g albume, spinaci freschi saltati e pane ai cereali (1 uovo, 150g albume, spinaci, 50g pane cereali, 5g evo)",
          "kcal": 445.0,
          "protein_g": 35.0,
          "carbs_g": 35.0,
          "fat_g": 13.0,
          "sugars_g": 3.5,
          "water_l": 0.8,
          "notes": "Cena essenziale e bilanciata a rapido assorbimento",
          "id": 4
        }
      ],
      "total_kcal": 1525.0,
      "total_protein": 121.0,
      "total_carbs": 147.0,
      "total_fat": 34.5,
      "total_sugars": 25.3,
      "total_water_l": 2.1,
      "daily_notes": "Lunedì demo: 1525.0 kcal (target 1600 centrato), 121.0g pro e 34.5g grassi. Bilancio ideale: rispetto del deficit calorico moderato senza sensazione di fame o cali energetici.",
      "steps": 0,
      "active_kcal": 400.0,
      "resting_kcal": 1750.0,
      "real_tdee": 2150.0
    },
    "2026-10-27": {
      "date": "2026-10-27",
      "weekday": "Martedì",
      "meals": [
        {
          "type": "Colazione",
          "description": "Porridge proteico d'avena con mirtilli freschi e semi di chia (45g avena, 20g whey, 10g chia, 150ml latte vegetale)",
          "kcal": 405.0,
          "protein_g": 27.5,
          "carbs_g": 41.0,
          "fat_g": 11.5,
          "sugars_g": 7.5,
          "water_l": 0.4,
          "notes": "Colazione ricca di fibre solubili e proteine a lento rilascio",
          "id": 1
        },
        {
          "type": "Pranzo",
          "description": "Riso basmati integrale con petto di pollo alle erbe e zucchine trifolate (70g riso, 180g pollo, 150g zucchine, 10g evo)",
          "kcal": 525.0,
          "protein_g": 43.0,
          "carbs_g": 56.0,
          "fat_g": 11.5,
          "sugars_g": 4.0,
          "water_l": 0.6,
          "notes": "Pranzo classico bilanciato ad alta digeribilità",
          "id": 2
        },
        {
          "type": "Spuntino",
          "description": "Yogurt greco magro con gherigli di noce (150g yogurt greco 0%, 15g noci)",
          "kcal": 185.0,
          "protein_g": 16.5,
          "carbs_g": 6.5,
          "fat_g": 9.5,
          "sugars_g": 5.0,
          "water_l": 0.3,
          "notes": "Snack pomeridiano spezza-fame ricco di grassi buoni",
          "id": 3
        },
        {
          "type": "Cena",
          "description": "Filetto di orata al cartoccio con patate novelle al rosmarino e fagiolini (180g orata, 150g patate, 150g fagiolini, 8g evo)",
          "kcal": 475.0,
          "protein_g": 42.0,
          "carbs_g": 43.0,
          "fat_g": 10.0,
          "sugars_g": 4.5,
          "water_l": 0.8,
          "notes": "Cena leggera ad altissima digeribilità ideale per il sonno",
          "id": 4
        }
      ],
      "total_kcal": 1590.0,
      "total_protein": 129.0,
      "total_carbs": 146.5,
      "total_fat": 42.5,
      "total_sugars": 21.0,
      "total_water_l": 2.1,
      "daily_notes": "Martedì demo: 1590.0 kcal (target 1600 centrato), 129.0g pro e 42.5g grassi. Giornata perfettamente bilanciata: introito calorico in target e zuccheri semplici contenuti.",
      "steps": 0,
      "active_kcal": 400.0,
      "resting_kcal": 1750.0,
      "real_tdee": 2150.0
    },
    "2026-10-28": {
      "date": "2026-10-28",
      "weekday": "Mercoledì",
      "meals": [
        {
          "type": "Colazione",
          "description": "Pancake d'avena e albume con yogurt greco 0% e frutti di bosco (40g farina d'avena, 120g albume, 50g yogurt greco)",
          "kcal": 385.0,
          "protein_g": 28.0,
          "carbs_g": 38.5,
          "fat_g": 8.0,
          "sugars_g": 6.0,
          "water_l": 0.4,
          "notes": "Pancake soffici ad alto valore biologico",
          "id": 1
        },
        {
          "type": "Pranzo",
          "description": "Pasta integrale con trancio di salmone, pomodorini datterini e rucola (75g pasta, 100g salmone, 100g pomodorini, 5g evo)",
          "kcal": 535.0,
          "protein_g": 37.0,
          "carbs_g": 59.0,
          "fat_g": 13.5,
          "sugars_g": 4.5,
          "water_l": 0.6,
          "notes": "Fonte eccellente di Omega-3 e carboidrati complessi",
          "id": 2
        },
        {
          "type": "Spuntino",
          "description": "Mela fresca a fette con burro d'arachidi 100% puro (150g mela, 15g burro arachidi)",
          "kcal": 175.0,
          "protein_g": 4.5,
          "carbs_g": 22.0,
          "fat_g": 7.5,
          "sugars_g": 14.0,
          "water_l": 0.3,
          "notes": "Energia pronta con fibre e micronutrienti",
          "id": 3
        },
        {
          "type": "Cena",
          "description": "Tagliata di manzo magro con rucola selvatica, pomodorini e pane di segale (160g manzo, 10g grana, rucola, 50g pane segale, 5g evo)",
          "kcal": 485.0,
          "protein_g": 44.0,
          "carbs_g": 36.0,
          "fat_g": 14.0,
          "sugars_g": 3.0,
          "water_l": 0.8,
          "notes": "Apporto di ferro biodisponibile e proteine nobili",
          "id": 4
        }
      ],
      "total_kcal": 1580.0,
      "total_protein": 113.5,
      "total_carbs": 155.5,
      "total_fat": 43.0,
      "total_sugars": 27.5,
      "total_water_l": 2.1,
      "daily_notes": "Mercoledì demo: 1580.0 kcal (target 1600 centrato), 113.5g pro e 43.0g grassi. Ottima aderenza nutrizionale: proteine elevate a supporto della massa magra e idratazione corretta.",
      "steps": 0,
      "active_kcal": 400.0,
      "resting_kcal": 1750.0,
      "real_tdee": 2150.0
    },
    "2026-10-29": {
      "date": "2026-10-29",
      "weekday": "Giovedì",
      "meals": [
        {
          "type": "Colazione",
          "description": "Toast di pane integrale con uova in camicia e fettine di avocado (60g pane integrale, 2 uova, 30g avocado)",
          "kcal": 415.0,
          "protein_g": 23.5,
          "carbs_g": 32.0,
          "fat_g": 17.5,
          "sugars_g": 3.0,
          "water_l": 0.4,
          "notes": "Colazione bilanciata con grassi monoinsaturi e proteine nobili",
          "id": 1
        },
        {
          "type": "Pranzo",
          "description": "Quinoa con fesa di tacchino ai ferri, peperoni grigliati e mandorle (70g quinoa, 170g tacchino, 100g peperoni, 10g mandorle)",
          "kcal": 505.0,
          "protein_g": 42.5,
          "carbs_g": 49.0,
          "fat_g": 12.0,
          "sugars_g": 4.2,
          "water_l": 0.6,
          "notes": "Profilo aminoacidico completo e ricco di minerali",
          "id": 2
        },
        {
          "type": "Spuntino",
          "description": "Toast croccante di segale con fesa di tacchino e formaggio light (40g pane segale, 60g tacchino, 20g formaggio magro)",
          "kcal": 180.0,
          "protein_g": 18.0,
          "carbs_g": 17.0,
          "fat_g": 3.5,
          "sugars_g": 2.0,
          "water_l": 0.3,
          "notes": "Spuntino salato ad altissimo contenuto proteico",
          "id": 3
        },
        {
          "type": "Cena",
          "description": "Trancio di merluzzo con crema di zucca al forno e crostini integrali (200g merluzzo, 200g zucca, 40g crostini integrali, 8g evo)",
          "kcal": 460.0,
          "protein_g": 41.5,
          "carbs_g": 42.0,
          "fat_g": 9.5,
          "sugars_g": 6.5,
          "water_l": 0.8,
          "notes": "Volume saziante ad elevata densità di micronutrienti",
          "id": 4
        }
      ],
      "total_kcal": 1560.0,
      "total_protein": 125.5,
      "total_carbs": 140.0,
      "total_fat": 42.5,
      "total_sugars": 15.7,
      "total_water_l": 2.1,
      "daily_notes": "Giovedì demo: 1560.0 kcal (target 1600 centrato), 125.5g pro e 42.5g grassi. Alimentazione pulita e saziante: pasti a densità nutrizionale elevata e glicemia stabile.",
      "steps": 0,
      "active_kcal": 400.0,
      "resting_kcal": 1750.0,
      "real_tdee": 2150.0
    },
    "2026-10-30": {
      "date": "2026-10-30",
      "weekday": "Venerdì",
      "meals": [
        {
          "type": "Colazione",
          "description": "Yogurt bowl con yogurt greco magro, granola d'avena integrale e banana (150g yogurt greco 0%, 30g granola, 60g banana)",
          "kcal": 395.0,
          "protein_g": 26.0,
          "carbs_g": 46.0,
          "fat_g": 7.5,
          "sugars_g": 11.0,
          "water_l": 0.4,
          "notes": "Bowl fresca e saziante con probiotici e micronutrienti",
          "id": 1
        },
        {
          "type": "Pranzo",
          "description": "Poke bowl con riso venere, tartare di tonno al naturale, edamame e cetrioli (70g riso venere, 120g tonno, 50g edamame, cetriolo, 5g evo)",
          "kcal": 515.0,
          "protein_g": 41.0,
          "carbs_g": 53.0,
          "fat_g": 11.0,
          "sugars_g": 3.8,
          "water_l": 0.6,
          "notes": "Pranzo fresco a basso indice glicemico",
          "id": 2
        },
        {
          "type": "Spuntino",
          "description": "Smoothie proteico con mirtilli, latte di soia e whey isolate (150ml latte soia, 15g whey, 50g mirtilli)",
          "kcal": 170.0,
          "protein_g": 19.0,
          "carbs_g": 13.0,
          "fat_g": 3.0,
          "sugars_g": 7.0,
          "water_l": 0.3,
          "notes": "Idratazione e recupero muscolare",
          "id": 3
        },
        {
          "type": "Cena",
          "description": "Omelette con 1 uovo e 150g albume, spinaci freschi saltati e pane ai cereali (1 uovo, 150g albume, spinaci, 50g pane cereali, 5g evo)",
          "kcal": 445.0,
          "protein_g": 35.0,
          "carbs_g": 35.0,
          "fat_g": 13.0,
          "sugars_g": 3.5,
          "water_l": 0.8,
          "notes": "Cena essenziale e bilanciata a rapido assorbimento",
          "id": 4
        }
      ],
      "total_kcal": 1525.0,
      "total_protein": 121.0,
      "total_carbs": 147.0,
      "total_fat": 34.5,
      "total_sugars": 25.3,
      "total_water_l": 2.1,
      "daily_notes": "Venerdì demo: 1525.0 kcal (target 1600 centrato), 121.0g pro e 34.5g grassi. Bilancio ideale: rispetto del deficit calorico moderato senza sensazione di fame o cali energetici.",
      "steps": 0,
      "active_kcal": 400.0,
      "resting_kcal": 1750.0,
      "real_tdee": 2150.0
    },
    "2026-10-31": {
      "date": "2026-10-31",
      "weekday": "Sabato",
      "meals": [
        {
          "type": "Colazione",
          "description": "Porridge proteico d'avena con mirtilli freschi e semi di chia (45g avena, 20g whey, 10g chia, 150ml latte vegetale)",
          "kcal": 405.0,
          "protein_g": 27.5,
          "carbs_g": 41.0,
          "fat_g": 11.5,
          "sugars_g": 7.5,
          "water_l": 0.4,
          "notes": "Colazione ricca di fibre solubili e proteine a lento rilascio",
          "id": 1
        },
        {
          "type": "Pranzo",
          "description": "Riso basmati integrale con petto di pollo alle erbe e zucchine trifolate (70g riso, 180g pollo, 150g zucchine, 10g evo)",
          "kcal": 525.0,
          "protein_g": 43.0,
          "carbs_g": 56.0,
          "fat_g": 11.5,
          "sugars_g": 4.0,
          "water_l": 0.6,
          "notes": "Pranzo classico bilanciato ad alta digeribilità",
          "id": 2
        },
        {
          "type": "Spuntino",
          "description": "Yogurt greco magro con gherigli di noce (150g yogurt greco 0%, 15g noci)",
          "kcal": 185.0,
          "protein_g": 16.5,
          "carbs_g": 6.5,
          "fat_g": 9.5,
          "sugars_g": 5.0,
          "water_l": 0.3,
          "notes": "Snack pomeridiano spezza-fame ricco di grassi buoni",
          "id": 3
        },
        {
          "type": "Cena",
          "description": "Filetto di orata al cartoccio con patate novelle al rosmarino e fagiolini (180g orata, 150g patate, 150g fagiolini, 8g evo)",
          "kcal": 475.0,
          "protein_g": 42.0,
          "carbs_g": 43.0,
          "fat_g": 10.0,
          "sugars_g": 4.5,
          "water_l": 0.8,
          "notes": "Cena leggera ad altissima digeribilità ideale per il sonno",
          "id": 4
        }
      ],
      "total_kcal": 1590.0,
      "total_protein": 129.0,
      "total_carbs": 146.5,
      "total_fat": 42.5,
      "total_sugars": 21.0,
      "total_water_l": 2.1,
      "daily_notes": "Sabato demo: 1590.0 kcal (target 1600 centrato), 129.0g pro e 42.5g grassi. Giornata perfettamente bilanciata: introito calorico in target e zuccheri semplici contenuti.",
      "steps": 0,
      "active_kcal": 400.0,
      "resting_kcal": 1750.0,
      "real_tdee": 2150.0
    },
    "2026-11-01": {
      "date": "2026-11-01",
      "weekday": "Domenica",
      "meals": [
        {
          "type": "Colazione",
          "description": "Pancake d'avena e albume con yogurt greco 0% e frutti di bosco (40g farina d'avena, 120g albume, 50g yogurt greco)",
          "kcal": 385.0,
          "protein_g": 28.0,
          "carbs_g": 38.5,
          "fat_g": 8.0,
          "sugars_g": 6.0,
          "water_l": 0.4,
          "notes": "Pancake soffici ad alto valore biologico",
          "id": 1
        },
        {
          "type": "Pranzo",
          "description": "Pasta integrale con trancio di salmone, pomodorini datterini e rucola (75g pasta, 100g salmone, 100g pomodorini, 5g evo)",
          "kcal": 535.0,
          "protein_g": 37.0,
          "carbs_g": 59.0,
          "fat_g": 13.5,
          "sugars_g": 4.5,
          "water_l": 0.6,
          "notes": "Fonte eccellente di Omega-3 e carboidrati complessi",
          "id": 2
        },
        {
          "type": "Spuntino",
          "description": "Mela fresca a fette con burro d'arachidi 100% puro (150g mela, 15g burro arachidi)",
          "kcal": 175.0,
          "protein_g": 4.5,
          "carbs_g": 22.0,
          "fat_g": 7.5,
          "sugars_g": 14.0,
          "water_l": 0.3,
          "notes": "Energia pronta con fibre e micronutrienti",
          "id": 3
        },
        {
          "type": "Cena",
          "description": "Tagliata di manzo magro con rucola selvatica, pomodorini e pane di segale (160g manzo, 10g grana, rucola, 50g pane segale, 5g evo)",
          "kcal": 485.0,
          "protein_g": 44.0,
          "carbs_g": 36.0,
          "fat_g": 14.0,
          "sugars_g": 3.0,
          "water_l": 0.8,
          "notes": "Apporto di ferro biodisponibile e proteine nobili",
          "id": 4
        }
      ],
      "total_kcal": 1580.0,
      "total_protein": 113.5,
      "total_carbs": 155.5,
      "total_fat": 43.0,
      "total_sugars": 27.5,
      "total_water_l": 2.1,
      "daily_notes": "Domenica demo: 1580.0 kcal (target 1600 centrato), 113.5g pro e 43.0g grassi. Ottima aderenza nutrizionale: proteine elevate a supporto della massa magra e idratazione corretta.",
      "steps": 0,
      "active_kcal": 400.0,
      "resting_kcal": 1750.0,
      "real_tdee": 2150.0
    },
    "2026-11-02": {
      "date": "2026-11-02",
      "weekday": "Lunedì",
      "meals": [
        {
          "type": "Colazione",
          "description": "Toast di pane integrale con uova in camicia e fettine di avocado (60g pane integrale, 2 uova, 30g avocado)",
          "kcal": 415.0,
          "protein_g": 23.5,
          "carbs_g": 32.0,
          "fat_g": 17.5,
          "sugars_g": 3.0,
          "water_l": 0.4,
          "notes": "Colazione bilanciata con grassi monoinsaturi e proteine nobili",
          "id": 1
        },
        {
          "type": "Pranzo",
          "description": "Quinoa con fesa di tacchino ai ferri, peperoni grigliati e mandorle (70g quinoa, 170g tacchino, 100g peperoni, 10g mandorle)",
          "kcal": 505.0,
          "protein_g": 42.5,
          "carbs_g": 49.0,
          "fat_g": 12.0,
          "sugars_g": 4.2,
          "water_l": 0.6,
          "notes": "Profilo aminoacidico completo e ricco di minerali",
          "id": 2
        },
        {
          "type": "Spuntino",
          "description": "Toast croccante di segale con fesa di tacchino e formaggio light (40g pane segale, 60g tacchino, 20g formaggio magro)",
          "kcal": 180.0,
          "protein_g": 18.0,
          "carbs_g": 17.0,
          "fat_g": 3.5,
          "sugars_g": 2.0,
          "water_l": 0.3,
          "notes": "Spuntino salato ad altissimo contenuto proteico",
          "id": 3
        },
        {
          "type": "Cena",
          "description": "Trancio di merluzzo con crema di zucca al forno e crostini integrali (200g merluzzo, 200g zucca, 40g crostini integrali, 8g evo)",
          "kcal": 460.0,
          "protein_g": 41.5,
          "carbs_g": 42.0,
          "fat_g": 9.5,
          "sugars_g": 6.5,
          "water_l": 0.8,
          "notes": "Volume saziante ad elevata densità di micronutrienti",
          "id": 4
        }
      ],
      "total_kcal": 1560.0,
      "total_protein": 125.5,
      "total_carbs": 140.0,
      "total_fat": 42.5,
      "total_sugars": 15.7,
      "total_water_l": 2.1,
      "daily_notes": "Lunedì demo: 1560.0 kcal (target 1600 centrato), 125.5g pro e 42.5g grassi. Alimentazione pulita e saziante: pasti a densità nutrizionale elevata e glicemia stabile.",
      "steps": 0,
      "active_kcal": 400.0,
      "resting_kcal": 1750.0,
      "real_tdee": 2150.0
    }
  }
}
"""#
}
