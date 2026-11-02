//
//  DiaryView.swift
//  MacroBara
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DiaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    
    @State private var selectedDate: Date = Date()
    @State private var showingAddMealSheet = false
    @State private var showingFilePicker = false
    
    private var currentProfile: UserProfile {
        profiles.first ?? UserProfile()
    }
    
    private var activeLog: DailyLog {
        let dateStr = DailyLog.dateFormatter.string(from: selectedDate)
        if let found = logs.first(where: { $0.dateString == dateStr && !$0.meals.isEmpty }) ??
                       logs.first(where: { $0.dateString == dateStr }) {
            return found
        }
        return DailyLog(date: selectedDate, restingKcal: currentProfile.bmrKcal)
    }
    
    private var grade: DailyGrade {
        NutritionEngine.shared.calculateGrade(for: activeLog, profile: currentProfile)
    }
    
    /// Ordine cronologico fisiologico rigoroso:
    /// 1. Colazione -> 2. Spuntino Mattina (se presente) -> 3. Pranzo -> 4. Spuntino Pomeriggio (se presente) -> 5. Cena -> 6. Spuntino Sera (se presente) -> 7. Bevande
    private var sortedMeals: [MealEntry] {
        activeLog.meals.sorted { m1, m2 in
            let o1 = mealChronologicalOrder(m1)
            let o2 = mealChronologicalOrder(m2)
            if o1 != o2 {
                return o1 < o2
            }
            return m1.date < m2.date
        }
    }
    
    private func mealChronologicalOrder(_ meal: MealEntry) -> Double {
        let title = meal.title.lowercased()
        let notes = meal.notes.lowercased()
        let desc = meal.foodDescription.lowercased()
        let raw = meal.mealTypeRaw.lowercased()
        
        // 1. Colazione (SEMPRE 100 - non può essere superata da nessuno spuntino)
        if title.contains("colazione") || desc.contains("colazione") || (raw.contains("colazione") && !title.contains("spuntino") && !title.contains("snack")) {
            return 100
        }
        
        // 2. Spuntino Mattina (200)
        if title.contains("spuntino mattina") || title.contains("mattin") || notes.contains("mattina") {
            return 200
        }
        
        // 3. Pranzo (SEMPRE 300)
        if title.contains("pranzo") || desc.contains("pranzo") || (raw.contains("pranzo") && !title.contains("spuntino")) {
            return 300
        }
        
        // 4. Spuntino Pomeriggio (400)
        if title.contains("spuntino pomeriggio") || title.contains("pomerigg") || notes.contains("pomeriggio") {
            return 400
        }
        
        // 5. Cena (SEMPRE 500)
        if title.contains("cena") || desc.contains("cena") || (raw.contains("cena") && !title.contains("spuntino")) {
            return 500
        }
        
        // 6. Spuntino Sera / Notte (600)
        if title.contains("spuntino sera") || title.contains("sera") || title.contains("notte") || notes.contains("sera") {
            return 600
        }
        
        // 7. Snack / Spuntino generico: disambigua con l'orario di registrazione
        if raw.contains("spuntino") || raw.contains("snack") || title.contains("spuntino") || title.contains("snack") || title.contains("sfizio") {
            let hour = Calendar.current.component(.hour, from: meal.date)
            if hour < 12 {
                return 200 // Spuntino Mattina
            } else if hour < 19 {
                return 400 // Spuntino Pomeriggio
            } else {
                return 600 // Spuntino Sera
            }
        }
        
        // 8. Bevande (700)
        if raw.contains("bevande") || meal.mealType == .bevande || desc.contains("acqua") || desc.contains("the") {
            return 700
        }
        
        return 800
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Selettore Data compatto
                    datePickerRow
                    
                    // Card Grado Tier List e Focus Fisiologico
                    tierGradeCard
                    
                    // Lista Pasti
                    mealsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .refreshable {
                DataImporter.shared.consolidateAndDeduplicate(modelContext: modelContext)
                try? modelContext.save()
            }
            .background(Theme.pageBackground.ignoresSafeArea())
            .navigationTitle("Diario Pasti")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            DataImporter.shared.cleanupAndImport(modelContext: modelContext)
                        } label: {
                            Label("Ripristina Storico Reale (14 Giorni)", systemImage: "arrow.clockwise")
                        }
                        
                        Button {
                            showingFilePicker = true
                        } label: {
                            Label("Carica da iCloud Drive (history.json)", systemImage: "folder")
                        }
                    } label: {
                        Image(systemName: "icloud.and.arrow.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.coralTerracotta)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddMealSheet = true
                    } label: {
                        Label("Aggiungi Pasto", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddMealSheet) {
                AddMealView(log: activeLog)
            }
            .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.json]) { result in
                switch result {
                case .success(let url):
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        if let data = try? Data(contentsOf: url) {
                            DataImporter.shared.cleanupAndImport(modelContext: modelContext, customData: data)
                        }
                    }
                case .failure(let error):
                    print("Errore picker: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var datePickerRow: some View {
        GlassCard {
            HStack {
                Button {
                    if let prev = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) {
                        selectedDate = prev
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(.body, design: .rounded).bold())
                        .foregroundStyle(Theme.coralTerracotta)
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(activeLog.weekday)
                        .font(.system(.subheadline, design: .rounded).bold())
                    Text(DailyLog.dateFormatter.string(from: selectedDate))
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    if let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
                        selectedDate = next
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(.body, design: .rounded).bold())
                        .foregroundStyle(Theme.coralTerracotta)
                }
            }
        }
    }
    
    private var tierGradeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(grade.title)
                            .font(.system(.headline, design: .rounded).bold())
                        Text(grade.summary)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    TierBadgeView(grade: grade.grade, color: grade.color, size: 48)
                }
                
                Divider()
                
                VStack(spacing: 8) {
                    ForEach(grade.breakdown, id: \.title) { item in
                        HStack {
                            Circle()
                                .fill(item.color)
                                .frame(width: 8, height: 8)
                            Text(item.title)
                                .font(.system(.caption, design: .rounded).weight(.semibold))
                            Spacer()
                            Text(item.note)
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private var mealsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PASTI REGISTRATI")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            
            if activeLog.meals.isEmpty {
                GlassCard {
                    VStack(spacing: 12) {
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary.opacity(0.6))
                        Text("Nessun pasto registrato per oggi.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                        Button {
                            showingAddMealSheet = true
                        } label: {
                            Text("Registra Pasto")
                                .font(.system(.caption, design: .rounded).bold())
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Theme.accentEmerald)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
            } else {
                ForEach(sortedMeals) { meal in
                    mealCard(meal)
                }
            }
        }
    }
    
    private func mealCard(_ meal: MealEntry) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    Image(systemName: meal.mealType.iconName)
                        .foregroundStyle(Theme.accentEmerald)
                    Text(meal.title)
                        .font(.system(.subheadline, design: .rounded).bold())
                    
                    Spacer()
                    
                    Text("\(Int(meal.kcal)) kcal")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(Theme.accentCyan)
                    
                    Button(role: .destructive) {
                        deleteMeal(meal)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.coralTerracotta)
                            .padding(6)
                            .background(Theme.coralTerracotta.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.borderless)
                }
                
                Text(meal.foodDescription)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.primary)
                
                HStack(spacing: 12) {
                    macroBadge(label: "Pro", value: "\(Int(meal.proteinG))g", color: Theme.accentEmerald)
                    macroBadge(label: "Carb", value: "\(Int(meal.carbsG))g", color: Theme.accentAmber)
                    macroBadge(label: "Fat", value: "\(Int(meal.fatG))g", color: Theme.accentRose)
                    macroBadge(label: "Zuccheri", value: "\(Int(meal.sugarsG))g", color: meal.sugarsG <= 10 ? Theme.accentEmerald : Theme.accentRose)
                }
                
                if !meal.notes.isEmpty {
                    Text(meal.notes)
                        .font(.system(size: 11, design: .rounded).italic())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                deleteMeal(meal)
            } label: {
                Label("Elimina pasto", systemImage: "trash")
            }
        }
    }
    
    private func deleteMeal(_ meal: MealEntry) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            if let idx = activeLog.meals.firstIndex(where: { $0.id == meal.id }) {
                activeLog.meals.remove(at: idx)
            }
            modelContext.delete(meal)
            try? modelContext.save()
            
            let todayStr = DailyLog.dateFormatter.string(from: Date())
            let logDesc = FetchDescriptor<DailyLog>()
            let allLogs = (try? modelContext.fetch(logDesc)) ?? []
            let todayLog = allLogs.first(where: { $0.dateString == todayStr })
            let profileDesc = FetchDescriptor<UserProfile>()
            let profile = (try? modelContext.fetch(profileDesc))?.first
            WidgetSyncManager.shared.syncWidget(todayLog: todayLog, profile: profile, allLogs: allLogs)
        }
    }
    
    private func macroBadge(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
