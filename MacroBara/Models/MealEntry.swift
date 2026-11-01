//
//  MealEntry.swift
//  MacroBara
//

import Foundation
import SwiftData

enum MealType: String, CaseIterable, Codable {
    case colazione = "Colazione"
    case pranzo = "Pranzo"
    case cena = "Cena"
    case snack = "Snack"
    case spuntino = "Spuntino"
    case bevande = "Bevande"
    
    var iconName: String {
        switch self {
        case .colazione: return "sun.horizon.fill"
        case .pranzo: return "fork.knife"
        case .cena: return "moon.stars.fill"
        case .spuntino, .snack: return "leaf.fill"
        case .bevande: return "drop.fill"
        }
    }
    
    static var selectableCases: [MealType] {
        [.colazione, .pranzo, .cena, .spuntino, .bevande]
    }
}

@Model
final class MealEntry {
    var id: UUID
    var date: Date
    var mealTypeRaw: String
    var title: String
    var foodDescription: String
    var kcal: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var sugarsG: Double
    var waterL: Double
    var notes: String
    var presetName: String?
    
    var dailyLog: DailyLog?
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        mealType: MealType = .colazione,
        mealTypeRaw: String? = nil,
        title: String = "",
        foodDescription: String = "",
        kcal: Double = 0.0,
        proteinG: Double = 0.0,
        carbsG: Double = 0.0,
        fatG: Double = 0.0,
        sugarsG: Double = 0.0,
        waterL: Double = 0.0,
        notes: String = "",
        presetName: String? = nil
    ) {
        self.id = id
        self.date = date
        self.mealTypeRaw = mealTypeRaw ?? mealType.rawValue
        self.title = title.isEmpty ? (mealTypeRaw ?? mealType.rawValue) : title
        self.foodDescription = foodDescription
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.sugarsG = sugarsG
        self.waterL = waterL
        self.notes = notes
        self.presetName = presetName
    }
    
    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .colazione }
        set { mealTypeRaw = newValue.rawValue }
    }
}
