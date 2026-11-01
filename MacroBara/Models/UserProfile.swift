//
//  UserProfile.swift
//  MacroBara
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    var name: String
    var age: Int
    var heightCm: Double
    var startWeightKg: Double
    var currentWeightKg: Double
    var targetWeightKg: Double
    var normopesoMaxWeightKg: Double
    
    var bmrKcal: Double
    var defaultTdeeKcal: Double
    var targetKcal: Double
    var targetProteinG: Double
    var targetCarbsG: Double
    var targetFatG: Double
    var targetSugarMaxG: Double
    var targetWaterL: Double
    
    var startDate: Date
    
    init(
        name: String = "Marco Rossi",
        age: Int = 25,
        heightCm: Double = 180.0,
        startWeightKg: Double = 89.0,
        currentWeightKg: Double = 87.9,
        targetWeightKg: Double = 78.0,
        normopesoMaxWeightKg: Double = 80.7,
        bmrKcal: Double = 1750.0,
        defaultTdeeKcal: Double = 2150.0,
        targetKcal: Double = 1600.0,
        targetProteinG: Double = 130.0,
        targetCarbsG: Double = 170.0,
        targetFatG: Double = 50.0,
        targetSugarMaxG: Double = 40.0,
        targetWaterL: Double = 2.5,
        startDate: Date = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 21)) ?? Date()
    ) {
        self.name = name
        self.age = age
        self.heightCm = heightCm
        self.startWeightKg = startWeightKg
        self.currentWeightKg = currentWeightKg
        self.targetWeightKg = targetWeightKg
        self.normopesoMaxWeightKg = normopesoMaxWeightKg
        self.bmrKcal = bmrKcal
        self.defaultTdeeKcal = defaultTdeeKcal
        self.targetKcal = targetKcal
        self.targetProteinG = targetProteinG
        self.targetCarbsG = targetCarbsG
        self.targetFatG = targetFatG
        self.targetSugarMaxG = targetSugarMaxG
        self.targetWaterL = targetWaterL
        self.startDate = startDate
    }
    
    var currentBmi: Double {
        let heightM = heightCm / 100.0
        guard heightM > 0 else { return 0 }
        return (currentWeightKg / (heightM * heightM) * 10).rounded() / 10
    }
    
    var weightToNormopeso: Double {
        max(0, (currentWeightKg - normopesoMaxWeightKg * 10).rounded() / 10)
    }
    
    var weightToTarget: Double {
        max(0, (currentWeightKg - targetWeightKg * 10).rounded() / 10)
    }
    
    var totalLostKg: Double {
        max(0, ((startWeightKg - currentWeightKg) * 10).rounded() / 10)
    }
    
    var progressFraction: Double {
        let totalToLose = startWeightKg - targetWeightKg
        guard totalToLose > 0 else { return 1.0 }
        let currentLost = startWeightKg - currentWeightKg
        return min(1.0, max(0.0, currentLost / totalToLose))
    }
}
