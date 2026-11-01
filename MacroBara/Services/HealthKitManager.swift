//
//  HealthKitManager.swift
//  MacroBara
//

import Foundation
import HealthKit
import SwiftUI

@Observable
final class HealthKitManager {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    
    var isAuthorized: Bool = false
    var stepsToday: Int = 0
    var activeEnergyBurnedKcal: Double = 0.0
    var restingEnergyBurnedKcal: Double = 1750.0
    var latestWeightKg: Double? = nil
    
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    func requestAuthorization() async {
        guard isHealthKitAvailable else { return }
        
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let basalEnergyType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned),
              let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return
        }
        
        let typesToRead: Set<HKObjectType> = [
            stepType,
            activeEnergyType,
            basalEnergyType,
            bodyMassType
        ]
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            await MainActor.run {
                self.isAuthorized = true
            }
            await fetchTodayData()
        } catch {
            print("Errore autorizzazione HealthKit: \(error.localizedDescription)")
        }
    }
    
    func fetchTodayData() async {
        guard isHealthKitAvailable else { return }
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        // 1. Passi
        if let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            let steps = await fetchCumulativeSum(for: stepType, unit: .count(), predicate: predicate)
            await MainActor.run {
                self.stepsToday = Int(steps)
            }
        }
        
        // 2. Calorie Attive
        if let activeType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let activeKcal = await fetchCumulativeSum(for: activeType, unit: .kilocalorie(), predicate: predicate)
            await MainActor.run {
                self.activeEnergyBurnedKcal = (activeKcal * 10).rounded() / 10
            }
        }
        
        // 3. Calorie Riposo
        if let basalType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) {
            let basalKcal = await fetchCumulativeSum(for: basalType, unit: .kilocalorie(), predicate: predicate)
            if basalKcal > 0 {
                await MainActor.run {
                    self.restingEnergyBurnedKcal = (basalKcal * 10).rounded() / 10
                }
            }
        }
    }
    
    private func fetchCumulativeSum(for quantityType: HKQuantityType, unit: HKUnit, predicate: NSPredicate) async -> Double {
        await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
                guard let sum = result?.sumQuantity() else {
                    continuation.resume(returning: 0.0)
                    return
                }
                continuation.resume(returning: sum.doubleValue(for: unit))
            }
            healthStore.execute(query)
        }
    }
    
    // MARK: - Query Storico Multi-Giorno per Sincronizzazione iCloud & Assistente AI
    
    struct DailyHealthExport: Codable, Identifiable {
        var id: String { date }
        let date: String // YYYY-MM-DD
        let steps: Int
        let activeKcal: Double
        let restingKcal: Double
    }
    
    func fetchRecentHistory(daysCount: Int = 14) async -> [DailyHealthExport] {
        guard isHealthKitAvailable else { return [] }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let activeType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned),
              let basalType = HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned) else {
            return []
        }
        
        var results: [DailyHealthExport] = []
        let calendar = Calendar.current
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        for dayOffset in 0..<daysCount {
            guard let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let startOfDay = calendar.startOfDay(for: targetDate)
            let endOfDay: Date
            if dayOffset == 0 {
                endOfDay = now
            } else {
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { continue }
                endOfDay = nextDay
            }
            
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
            
            let steps = await fetchCumulativeSum(for: stepType, unit: .count(), predicate: predicate)
            let active = await fetchCumulativeSum(for: activeType, unit: .kilocalorie(), predicate: predicate)
            let basal = await fetchCumulativeSum(for: basalType, unit: .kilocalorie(), predicate: predicate)
            
            let dateStr = formatter.string(from: targetDate)
            results.append(DailyHealthExport(
                date: dateStr,
                steps: Int(steps),
                activeKcal: (active * 10).rounded() / 10,
                restingKcal: basal > 0 ? (basal * 10).rounded() / 10 : 1750.0
            ))
        }
        
        return results
    }
}
