//
//  WeighIn.swift
//  MacroBara
//

import Foundation
import SwiftData

@Model
final class WeighIn {
    var id: UUID
    var weekNumber: Int
    var date: Date
    var weightKg: Double
    var deltaPrevKg: Double
    var deltaTotalKg: Double
    var notes: String
    
    init(
        id: UUID = UUID(),
        weekNumber: Int = 0,
        date: Date = Date(),
        weightKg: Double = 89.0,
        deltaPrevKg: Double = 0.0,
        deltaTotalKg: Double = 0.0,
        notes: String = ""
    ) {
        self.id = id
        self.weekNumber = weekNumber
        self.date = date
        self.weightKg = weightKg
        self.deltaPrevKg = deltaPrevKg
        self.deltaTotalKg = deltaTotalKg
        self.notes = notes
    }
}
