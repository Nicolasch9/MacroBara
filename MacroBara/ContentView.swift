//
//  ContentView.swift
//  MacroBara
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    @State private var selectedTab: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                DashboardView()
            }
            
            Tab("Diario", systemImage: "book.pages.fill", value: 1) {
                DiaryView()
            }
            
            Tab("Scambi", systemImage: "arrow.triangle.2.circlepath", value: 2) {
                SmartSwapsView()
            }
            
            Tab("Progressi", systemImage: "chart.line.uptrend.xyaxis", value: 3) {
                WeightProgressView()
            }
            
            Tab("Profilo", image: "CapybaraTabIcon", value: 4) {
                ProfileView(isEmbeddedInTab: true)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(Theme.coralTerracotta)
        .preferredColorScheme(.light)
        .task {
            seedProfileIfNeeded()
            DataImporter.shared.consolidateAndDeduplicate(modelContext: modelContext)
            DataImporter.shared.importHistoryIfNeeded(modelContext: modelContext)
            if ICloudSyncService.shared.isFolderLinked {
                await ICloudSyncService.shared.exportHealthDataToICloud()
            }
        }
    }
    
    private func seedProfileIfNeeded() {
        if profiles.isEmpty {
            let profile = UserProfile()
            modelContext.insert(profile)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [UserProfile.self, DailyLog.self, MealEntry.self, WeighIn.self], inMemory: true)
}
