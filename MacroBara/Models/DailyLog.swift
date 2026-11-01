//
//  DailyLog.swift
//  MacroBara
//

import Foundation
import SwiftData

@Model
final class DailyLog {
    var id: UUID
    var date: Date
    var dateString: String
    var weekday: String
    var dailyNotes: String
    
    var steps: Int
    var activeKcal: Double
    var restingKcal: Double
    var waterL: Double
    
    @Relationship(deleteRule: .cascade, inverse: \MealEntry.dailyLog)
    var meals: [MealEntry] = []
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        dateString: String = "",
        weekday: String = "",
        dailyNotes: String = "",
        steps: Int = 0,
        activeKcal: Double = 0.0,
        restingKcal: Double = 1750.0,
        waterL: Double = 0.0
    ) {
        self.id = id
        self.date = date
        self.dateString = dateString.isEmpty ? DailyLog.dateFormatter.string(from: date) : dateString
        self.weekday = weekday.isEmpty ? DailyLog.weekdayFormatter.string(from: date).capitalized : weekday
        self.dailyNotes = dailyNotes
        self.steps = steps
        self.activeKcal = activeKcal
        self.restingKcal = restingKcal
        self.waterL = waterL
    }
    
    static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
    
    static let weekdayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "it_IT")
        df.dateFormat = "EEEE"
        return df
    }()
    
    var totalKcal: Double {
        meals.reduce(0.0) { $0 + $1.kcal }
    }
    
    var totalProtein: Double {
        meals.reduce(0.0) { $0 + $1.proteinG }
    }
    
    var totalCarbs: Double {
        meals.reduce(0.0) { $0 + $1.carbsG }
    }
    
    var totalFat: Double {
        meals.reduce(0.0) { $0 + $1.fatG }
    }
    
    var totalSugars: Double {
        meals.reduce(0.0) { $0 + $1.sugarsG }
    }
    
    var realTdee: Double {
        let bmr = max(restingKcal, 1750.0)
        if activeKcal > 0 {
            return max(2150.0, bmr + activeKcal)
        }
        return max(2150.0, bmr + 400.0)
    }
    
    var calorieBalance: Double {
        totalKcal - realTdee
    }
    
    var isPending: Bool {
        meals.isEmpty && totalKcal == 0
    }
}
