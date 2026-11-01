//
//  DashboardView.swift
//  MacroBara
//

import SwiftUI
import SwiftData

private enum GreenBentoTheme {
    // Sfondo card Bento Activity (Verde salvia pastello caldo)
    static let cardBackgroundStart = Color(red: 218/255, green: 236/255, blue: 220/255)
    static let cardBackgroundEnd = Color(red: 204/255, green: 226/255, blue: 207/255)
    static let cardGradient = LinearGradient(
        colors: [cardBackgroundStart, cardBackgroundEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Barra di sincronizzazione compatta
    static let syncBarBackground = Color(red: 228/255, green: 242/255, blue: 230/255)
    static let syncBarBorder = Color(red: 185/255, green: 215/255, blue: 188/255)
    
    // Tipografia ed icone
    static let darkGreenText = Color(red: 28/255, green: 60/255, blue: 34/255) // #1C3C22
    static let mutedGreenText = Color(red: 78/255, green: 112/255, blue: 84/255) // #4E7054
    static let trackLine = Color(red: 172/255, green: 206/255, blue: 174/255) // #ACCEAE
    static let badgeBg = Color(red: 190/255, green: 220/255, blue: 192/255) // #BEDCBF
    static let flagColor = Color(red: 45/255, green: 90/255, blue: 52/255)
}

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \DailyLog.date, order: .reverse) private var logs: [DailyLog]
    
    @State private var health = HealthKitManager.shared
    @State private var syncService = ICloudSyncService.shared
    @State private var isRefreshingWatch = false
    @State private var showingAddMealSheet = false
    @State private var showingFoodSearchSheet = false
    @State private var showingProfileSheet = false
    @State private var selectedMealTypeForAdd: MealType = .colazione
    @State private var scrollOffsetY: CGFloat = 0
    
    private var currentProfile: UserProfile {
        profiles.first ?? UserProfile()
    }
    
    private var todayLog: DailyLog {
        let todayStr = DailyLog.dateFormatter.string(from: Date())
        if let existing = logs.first(where: { $0.dateString == todayStr && !$0.meals.isEmpty }) ??
                          logs.first(where: { $0.dateString == todayStr }) {
            return existing
        }
        return DailyLog(date: Date(), restingKcal: currentProfile.bmrKcal)
    }
    
    private var grade: DailyGrade {
        NutritionEngine.shared.calculateGrade(for: todayLog, profile: currentProfile)
    }
    
    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Morning, Marco"
        } else if hour < 18 {
            return "Pomeriggio, Marco"
        } else {
            return "Buonasera, Marco"
        }
    }
    
    // MARK: - Computed Analytics da Dashboard OS
    
    private var streakData: (current: Int, best: Int, last14: [(day: String, hasMeals: Bool, isToday: Bool)]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayStr = DailyLog.dateFormatter.string(from: today)
        
        // Mappa delle date con pasti effettivi (yyyy-MM-dd -> hasMeals)
        var trackedMap: [String: Bool] = [:]
        for l in logs {
            if !l.meals.isEmpty {
                trackedMap[l.dateString] = true
            }
        }
        
        // 1. Heatmap: genera esattamente gli ultimi 14 giorni da (today - 13) a today
        var last14Items: [(day: String, hasMeals: Bool, isToday: Bool)] = []
        for offset in (0..<14).reversed() {
            guard let d = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dStr = DailyLog.dateFormatter.string(from: d)
            let dayNum = String(dStr.suffix(2))
            let has = trackedMap[dStr] == true
            let isTod = (dStr == todayStr)
            last14Items.append((day: dayNum, hasMeals: has, isToday: isTod))
        }
        
        // 2. Calcolo streak attivo consecutivo a ritroso:
        // Se oggi ha già pasti registrati, lo streak include oggi.
        // Se oggi non ha ancora pasti registrati (giornata in corso!), la striscia NON è interrotta:
        // calcola la sequenza ininterrotta a partire da ieri.
        var streak = 0
        var checkDate = today
        let todayTracked = trackedMap[todayStr] == true
        
        if !todayTracked {
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
                checkDate = yesterday
            }
        }
        
        while true {
            let dStr = DailyLog.dateFormatter.string(from: checkDate)
            if trackedMap[dStr] == true {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        
        // Best streak: calcola la striscia record nella cronologia
        var bestStreak = 14
        let allTrackedDates = trackedMap.keys.compactMap { DailyLog.dateFormatter.date(from: $0) }.sorted()
        var currentRun = 0
        var prevDate: Date? = nil
        for d in allTrackedDates {
            if let p = prevDate {
                let diffDays = calendar.dateComponents([.day], from: p, to: d).day ?? 0
                if diffDays == 1 {
                    currentRun += 1
                } else if diffDays > 1 {
                    currentRun = 1
                }
            } else {
                currentRun = 1
            }
            if currentRun > bestStreak {
                bestStreak = currentRun
            }
            prevDate = d
        }
        bestStreak = max(bestStreak, max(14, streak))
        
        return (max(1, streak), bestStreak, last14Items)
    }
    
    private var weeklyDeficitStats: (avgDeficit: Double, totalDeficit: Double, fatLossKg: Double) {
        let recent7 = logs.sorted(by: { $0.date > $1.date }).prefix(7)
        guard !recent7.isEmpty else { return (620, 4340, 0.56) }
        let total = recent7.reduce(0.0) { $0 + max(0, $1.realTdee - $1.totalKcal) }
        let avg = total / Double(recent7.count)
        let fat = total / 7700.0
        return (avg.rounded(), total.rounded(), (fat * 100).rounded() / 100)
    }
    
    private var bmiValue: Double {
        let h = currentProfile.heightCm / 100.0
        guard h > 0 else { return 28.7 }
        return ((currentProfile.currentWeightKg / (h * h)) * 10).rounded() / 10
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // 1. Top Hero Card Dark Espresso (Card Arrotondata Stile Claude Design)
                    topEspressoHeroCard
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 16)
                    
                    VStack(spacing: 20) {
                        // 2. Streak di Tracciamento Consecutivo con Heatmap
                        streakHeatmapCard
                        
                        // 3. Daily Routine (Timeline Pasti Connessa)
                        dailyRoutineSection
                        
                        // 4. Deficit Medio Settimanale & Lipolisi
                        weeklyDeficitCard
                        
                        // 5. BMI Gauge & Composizione Corporea
                        bmiGaugeCard
                        
                        // 6. Focus Lipidi & Differenziazione Grassi (Tips)
                        lipidFocusTipsCard
                        
                        // 7. Apple Watch & Attività Fisica
                        appleWatchCard
                        
                        // 8. Percorso Peso & Normopeso
                        weightProgressCard
                        
                        // 9. Idratazione
                        waterTrackerCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .refreshable {
                await health.fetchTodayData()
                if health.stepsToday > 0 {
                    todayLog.steps = health.stepsToday
                }
                if health.activeEnergyBurnedKcal > 0 {
                    todayLog.activeKcal = health.activeEnergyBurnedKcal
                }
                if todayLog.restingKcal < 1750.0 {
                    todayLog.restingKcal = 1750.0
                }
            }
            .background(Theme.pageBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddMealSheet) {
                AddMealView(log: todayLog)
            }
            .sheet(isPresented: $showingFoodSearchSheet) {
                foodSearchQuickSheet
            }
            .sheet(isPresented: $showingProfileSheet) {
                ProfileView()
            }
            .task {
                await health.requestAuthorization()
                await health.fetchTodayData()
                if health.stepsToday > 0 {
                    todayLog.steps = health.stepsToday
                }
                if health.activeEnergyBurnedKcal > 0 {
                    todayLog.activeKcal = health.activeEnergyBurnedKcal
                }
                if health.restingEnergyBurnedKcal >= 1750.0 {
                    todayLog.restingKcal = health.restingEnergyBurnedKcal
                } else if todayLog.restingKcal < 1750.0 {
                    todayLog.restingKcal = 1750.0
                }
            }
        }
    }
    
    // MARK: - 1. Top Espresso Hero Card
    
    private var topEspressoHeroCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Top Bar: Avatar e Pulsanti Circolari
            HStack {
                // Avatar Capybara Zen (Tap apre Profilo Utente)
                Button {
                    showingProfileSheet = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Theme.coralTerracotta)
                            .frame(width: 48, height: 48)
                        
                        Image("CapybaraMascot")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .clipShape(Circle())
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Pulsanti Circolari Frosted
                HStack(spacing: 10) {
                    Button {
                        showingFoodSearchSheet = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    
                    Button {
                        showingAddMealSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                }
            }
            
            // Saluto
            Text(greetingText)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            // Metrica Principale: Calorie Oggi
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    Text("Calorie assunte oggi")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                    
                    Spacer()
                    
                    // Pill percentuale target
                    let pct = min(150, Int((todayLog.totalKcal / max(1, currentProfile.targetKcal)) * 100))
                    Text("\(pct)% del target")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.coralTerracotta.opacity(0.25))
                        .foregroundStyle(Color(red: 255/255, green: 165/255, blue: 145/255))
                        .clipShape(Capsule())
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(todayLog.totalKcal))")
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("/ \(Int(currentProfile.targetKcal))")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
                
                // Barra di Progresso Orizzontale Terracotta
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.14))
                            .frame(height: 7)
                        
                        let ratio = min(1.0, todayLog.totalKcal / max(1, currentProfile.targetKcal))
                        Capsule()
                            .fill(Theme.coralTerracotta)
                            .frame(width: max(8, geo.size.width * CGFloat(ratio)), height: 7)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: todayLog.totalKcal)
                    }
                }
                .frame(height: 7)
            }
            
            // 3 Card Bianche Embedded per i Dettagli Rapidi
            HStack(spacing: 10) {
                // Card 1: Kcal Rimanenti
                let remaining = max(0, Int(currentProfile.targetKcal - todayLog.totalKcal))
                miniWhiteMetricCard(
                    icon: "flame.fill",
                    iconColor: Theme.coralTerracotta,
                    value: "\(remaining)",
                    unit: "kcal",
                    label: "rimaste"
                )
                
                // Card 2: Proteine
                miniWhiteMetricCard(
                    icon: "dumbbell.fill",
                    iconColor: Color(red: 59/255, green: 130/255, blue: 246/255),
                    value: "\(Int(todayLog.totalProtein))",
                    unit: "g",
                    label: "pro"
                )
                
                // Card 3: Zuccheri
                miniWhiteMetricCard(
                    icon: "heart.fill",
                    iconColor: Color(red: 244/255, green: 63/255, blue: 94/255),
                    value: "\(Int(todayLog.totalSugars))",
                    unit: "g",
                    label: "zuccheri"
                )
            }
        }
        .padding(22)
        .background(Theme.heroEspressoGradient)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: Color.black.opacity(0.14), radius: 18, x: 0, y: 8)
    }
    
    // MARK: - 2. Streak di Tracciamento con Heatmap
    
    private var streakHeatmapCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Text("🔥")
                    .font(.system(size: 32))
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(streakData.current)")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.coralTerracotta)
                        Text("giorni consecutivi")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }
                    Text("Costanza di tracciamento alimentare")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Text("Record: \(streakData.best) gg")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(red: 245/255, green: 158/255, blue: 11/255).opacity(0.15))
                    .foregroundStyle(Color(red: 245/255, green: 158/255, blue: 11/255))
                    .clipShape(Capsule())
            }
            
            // Heatmap quadratini ultimi 14 giorni
            HStack(spacing: 5) {
                ForEach(Array(streakData.last14.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: 4) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    item.hasMeals ?
                                        Color(red: 16/255, green: 185/255, blue: 129/255) :
                                        (item.isToday ? Color(red: 245/255, green: 158/255, blue: 11/255).opacity(0.18) : Color(.systemGray5))
                                )
                                .frame(height: 22)
                            
                            if item.isToday && !item.hasMeals {
                                RoundedRectangle(cornerRadius: 4)
                                    .strokeBorder(Color(red: 245/255, green: 158/255, blue: 11/255), lineWidth: 1)
                            }
                        }
                        
                        Text(item.day)
                            .font(.system(size: 9, weight: item.isToday ? .heavy : .semibold, design: .rounded))
                            .foregroundStyle(item.isToday ? Theme.coralTerracotta : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
    
    private func miniWhiteMetricCard(icon: String, iconColor: Color, value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(iconColor)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                Text(unit)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    // MARK: - 2. Daily Routine Section (Timeline Pasti)
    
    private var dailyRoutineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Daily routine")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button {
                    showingAddMealSheet = true
                } label: {
                    Text("+ Aggiungi")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.coralTerracotta)
                }
            }
            .padding(.horizontal, 4)
            
            // Card Bianca della Timeline
            VStack(spacing: 0) {
                let slots = routineSlots
                ForEach(Array(slots.enumerated()), id: \.offset) { index, slot in
                    timelineRow(slot: slot, isLast: index == slots.count - 1)
                }
            }
            .padding(18)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 26))
            .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 5)
        }
    }
    
    private struct RoutineSlot {
        var mealType: MealType
        var defaultTime: String
        var targetKcalHint: String
        var icon: String
        var registeredMeal: MealEntry?
        var isNext: Bool
    }
    
    private var routineSlots: [RoutineSlot] {
        let types: [(MealType, String, String, String)] = [
            (.colazione, "08:00", "~410 kcal", "cup.and.saucer.fill"),
            (.pranzo, "13:00", "~550 kcal", "fork.knife"),
            (.snack, "17:00", "~200 kcal", "apple.logo"),
            (.cena, "20:30", "~450 kcal", "moon.stars.fill")
        ]
        
        var foundNext = false
        var slots: [RoutineSlot] = []
        
        for (mType, time, hint, icon) in types {
            let existing = todayLog.meals.first(where: { $0.mealType == mType })
            var isNext = false
            if existing == nil && !foundNext {
                isNext = true
                foundNext = true
            }
            slots.append(RoutineSlot(
                mealType: mType,
                defaultTime: time,
                targetKcalHint: hint,
                icon: icon,
                registeredMeal: existing,
                isNext: isNext
            ))
        }
        
        return slots
    }
    
    private func timelineRow(slot: RoutineSlot, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Indicatore Circolare con Linea Connettore
            VStack(spacing: 0) {
                if let _ = slot.registeredMeal {
                    // Checkmark Nero come in foto
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white)
                    }
                } else {
                    // Anello Vuoto
                    Circle()
                        .stroke(Color.secondary.opacity(0.35), lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
                
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 1.5, height: 38)
                }
            }
            
            // Icona/Thumbnail Alimento
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .frame(width: 42, height: 42)
                
                Image(systemName: slot.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(slot.registeredMeal != nil ? Color.primary : Color.secondary)
            }
            
            // Dettagli Pasto
            VStack(alignment: .leading, spacing: 3) {
                if let meal = slot.registeredMeal {
                    Text(meal.title.isEmpty ? slot.mealType.rawValue : meal.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    Text("\(slot.defaultTime) • \(Int(meal.kcal)) kcal • \(Int(meal.proteinG))g Pro")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    Text(slot.mealType.rawValue)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.primary.opacity(0.85))
                    
                    Text("\(slot.defaultTime) • Target \(slot.targetKcalHint)")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // Badge "Up next" / "Prossimo" come in foto
            if slot.isNext {
                Text("Prossimo")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.coralTerracotta)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedMealTypeForAdd = slot.mealType
            showingAddMealSheet = true
        }
    }
    
    // MARK: - 3. Deficit Medio Settimanale
    
    private var weeklyDeficitCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Text("⚡")
                        .font(.system(size: 20))
                    Text("DEFICIT MEDIO & LIPOLISI")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Ultimi 7 giorni")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("-\(Int(weeklyDeficitStats.avgDeficit))")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(red: 16/255, green: 185/255, blue: 129/255))
                    Text("kcal/die di deficit medio")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 3) {
                    Text("~\(String(format: "%.2f", weeklyDeficitStats.fatLossKg)) kg")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.coralTerracotta)
                    Text("grasso ossidato (7.700 kcal/kg)")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            
            Text("Deficit cumulato settimana: -\(Int(weeklyDeficitStats.totalDeficit)) kcal. Mantenere 500-700 kcal/die assicura una lipolisi costante proteggendo i tessuti magri.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - 4. BMI Gauge Card
    
    private var bmiGaugeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("INDICE DI MASSA CORPOREA (BMI)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(String(format: "%.1f", bmiValue))")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("(Sovrappeso Lieve)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 245/255, green: 158/255, blue: 11/255))
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Target Normopeso")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("≤ 80.7 kg (24.9)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 16/255, green: 185/255, blue: 129/255))
                }
            }
            
            // Barra Orizzontale a 4 Categorie
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    HStack(spacing: 2) {
                        // Sottopeso < 18.5 (14%)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 34/255, green: 211/255, blue: 238/255))
                            .frame(width: w * 0.14)
                        
                        // Normopeso 18.5 - 24.9 (26%)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 16/255, green: 185/255, blue: 129/255))
                            .frame(width: w * 0.26)
                        
                        // Sovrappeso 25.0 - 29.9 (20%)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 245/255, green: 158/255, blue: 11/255))
                            .frame(width: w * 0.20)
                        
                        // Obesità >= 30.0 (38%)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 244/255, green: 63/255, blue: 94/255))
                            .frame(width: max(10, w * 0.38))
                    }
                    
                    // Pin Posizione Attuale (BMI 28.7)
                    let pos = max(0.05, min(0.95, (bmiValue - 15.0) / (40.0 - 15.0)))
                    VStack(spacing: 0) {
                        Capsule()
                            .fill(Color.primary)
                            .frame(width: 4, height: 18)
                    }
                    .offset(x: w * CGFloat(pos) - 2)
                }
            }
            .frame(height: 14)
            
            // Scala Limiti Numerici
            HStack {
                Text("15.0")
                Spacer()
                Text("18.5")
                Spacer()
                Text("24.9")
                Spacer()
                Text("29.9")
                Spacer()
                Text("40.0")
            }
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
            
            // 2 Badge Categorie Chiave
            HStack(spacing: 8) {
                bmiCategoryBadge(title: "Normopeso", range: "18.5-24.9", isTarget: true, isCurrent: false, color: Color(red: 16/255, green: 185/255, blue: 129/255))
                bmiCategoryBadge(title: "Sovrappeso", range: "25.0-29.9", isTarget: false, isCurrent: true, color: Color(red: 245/255, green: 158/255, blue: 11/255))
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
    
    private func bmiCategoryBadge(title: String, range: String, isTarget: Bool, isCurrent: Bool, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Spacer()
                if isTarget {
                    Text("TARGET 🎯")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.15))
                        .clipShape(Capsule())
                }
                if isCurrent {
                    Text("SEI QUI 📍")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            Text("\(range) • \(isTarget ? "≤ 80.7 kg" : "80.8-97 kg")")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - 5. Focus Lipidi & Tips Nutrizionali
    
    private var lipidFocusTipsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    Text("🥑")
                        .font(.system(size: 20))
                    Text("FOCUS LIPIDI & STRATEGIA DEI GRASSI")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                let fatPct = Int((todayLog.totalFat / max(1, currentProfile.targetFatG)) * 100)
                Text("\(Int(todayLog.totalFat))g / 50g max (\(fatPct)%)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(todayLog.totalFat <= 50 ? Color(red: 16/255, green: 185/255, blue: 129/255) : Color(red: 244/255, green: 63/255, blue: 94/255))
            }
            
            // Consiglio Fisiologico Chiave
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(red: 245/255, green: 158/255, blue: 11/255))
                
                Text("1g di grasso = 9 kcal (contro 4 kcal/g di proteine e carboidrati). Un solo cucchiaio di olio EVO non dosato (+10g) apporta 90 kcal: dosalo con precisione per non erodere il deficit.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.85))
            }
            .padding(12)
            .background(Color(red: 245/255, green: 158/255, blue: 11/255).opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            
            // Tabella Tips: Grassi Insaturi vs Saturi
            VStack(spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    Text("🌿")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Grassi Insaturi (Privilegiare)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 16/255, green: 185/255, blue: 129/255))
                        Text("Olio EVO a crudo, noci, mandorle, semi di chia e acidi grassi Omega-3 da salmone fresco.")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Divider()
                
                HStack(alignment: .top, spacing: 10) {
                    Text("⚠️")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Grassi Saturi (Da moderare)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 245/255, green: 158/255, blue: 11/255))
                        Text("Formaggi stagionati, carni grasse lavorate e burro. Mantienili sotto il 10% dell'introito lipidico.")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - 6. Apple Watch & Attività Fisica (Bento Verde + Sync Compatto)
    
    private var averageStepsLast7Days: Int {
        let valid = logs.filter { $0.steps > 0 }
        let recent = Array(valid.prefix(7))
        guard !recent.isEmpty else { return 4209 }
        let sum = recent.reduce(0) { $0 + $1.steps }
        return max(1, sum / recent.count)
    }
    
    private func formatThousands(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    private var appleWatchCard: some View {
        VStack(spacing: 10) {
            // Sincronizzazione con Apple Watch piccola e sempre di colore verde col tasto per aggiornare
            compactAppleWatchSyncBar
            
            // Grafico verde Bento Activity (Fedelmente riproposto dal design Bento)
            bentoActivityCard
        }
    }
    
    private var compactAppleWatchSyncBar: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(GreenBentoTheme.badgeBg)
                    .frame(width: 28, height: 28)
                Image(systemName: "applewatch")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(GreenBentoTheme.darkGreenText)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 5) {
                    Text("Sincronizzazione Apple Watch")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(GreenBentoTheme.darkGreenText)
                    
                    Circle()
                        .fill(Color(red: 16/255, green: 185/255, blue: 129/255))
                        .frame(width: 6, height: 6)
                }
                
                Text("\(Int(todayLog.activeKcal)) kcal attive rilevate • HealthKit")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(GreenBentoTheme.mutedGreenText)
            }
            
            Spacer()
            
            Button {
                isRefreshingWatch = true
                Task {
                    await health.fetchTodayData()
                    if health.stepsToday > 0 {
                        todayLog.steps = health.stepsToday
                    }
                    if health.activeEnergyBurnedKcal > 0 {
                        todayLog.activeKcal = health.activeEnergyBurnedKcal
                    }
                    try? modelContext.save()
                    await syncService.exportHealthDataToICloud()
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    isRefreshingWatch = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .bold))
                        .rotationEffect(.degrees(isRefreshingWatch ? 360 : 0))
                        .animation(isRefreshingWatch ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default, value: isRefreshingWatch)
                    Text("Aggiorna")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(GreenBentoTheme.badgeBg)
                .foregroundStyle(GreenBentoTheme.darkGreenText)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(GreenBentoTheme.syncBarBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(GreenBentoTheme.syncBarBorder.opacity(0.7), lineWidth: 1)
        )
    }
    
    private var bentoActivityCard: some View {
        let steps = todayLog.steps
        let targetSteps = 7500
        let progress = min(1.0, max(0.04, Double(steps) / Double(targetSteps)))
        let avgSteps = averageStepsLast7Days
        
        let activityLevel: String = {
            if steps >= 10000 {
                return "Active"
            } else if steps >= 5000 {
                return "Moderate"
            } else {
                return "Light"
            }
        }()
        
        return VStack(alignment: .leading, spacing: 14) {
            // Header Sezione Bento
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Activity")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(GreenBentoTheme.darkGreenText)
                    
                    Text(activityLevel)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(GreenBentoTheme.mutedGreenText)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(GreenBentoTheme.badgeBg)
                        .frame(width: 38, height: 38)
                    Image(systemName: "figure.walk")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(GreenBentoTheme.darkGreenText)
                }
            }
            
            // Grafico Centrale: Barra Orizzontale con Cursore e Bandierina Traguardo
            GeometryReader { geo in
                let width = geo.size.width
                let knobX = min(width - 24, max(8, width * CGFloat(progress)))
                
                ZStack(alignment: .leading) {
                    // Linea di binario (Track)
                    Capsule()
                        .fill(GreenBentoTheme.trackLine)
                        .frame(height: 3)
                    
                    // Tratto percorso
                    Capsule()
                        .fill(GreenBentoTheme.darkGreenText.opacity(0.8))
                        .frame(width: knobX, height: 3)
                    
                    // Pallino cursore posizione
                    Circle()
                        .fill(GreenBentoTheme.darkGreenText)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                        .offset(x: max(0, knobX - 5))
                    
                    // Bandierina finale
                    HStack {
                        Spacer()
                        Image(systemName: "flag.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(GreenBentoTheme.flagColor)
                    }
                }
                .frame(height: 20)
            }
            .frame(height: 20)
            .padding(.vertical, 4)
            
            // Footer: Steps a sinistra, Average a destra
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(formatThousands(steps))
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(GreenBentoTheme.darkGreenText)
                    
                    Text("Steps")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(GreenBentoTheme.mutedGreenText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 1) {
                    Text(formatThousands(avgSteps))
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(GreenBentoTheme.darkGreenText)
                    
                    Text("Average")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(GreenBentoTheme.mutedGreenText)
                }
            }
        }
        .padding(18)
        .background(GreenBentoTheme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 3)
    }
    
    // MARK: - 4. Percorso Peso
    
    private var weightProgressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PESO CORPOREO")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    Text("\(String(format: "%.1f", currentProfile.currentWeightKg)) kg")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Verso Normopeso (80.7)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("-\(String(format: "%.1f", currentProfile.weightToNormopeso)) kg")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 16/255, green: 185/255, blue: 129/255))
                }
            }
            
            ProgressView(value: currentProfile.progressFraction)
                .tint(Theme.coralTerracotta)
            
            HStack {
                Text("Partenza: \(String(format: "%.1f", currentProfile.startWeightKg)) kg")
                Spacer()
                Text("Target: \(String(format: "%.1f", currentProfile.targetWeightKg)) kg")
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - 5. Idratazione
    
    private var waterTrackerCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("IDRATAZIONE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", todayLog.waterL))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("/ \(String(format: "%.1f", currentProfile.targetWaterL)) L")
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button {
                    todayLog.waterL = max(0, todayLog.waterL - 0.25)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary.opacity(0.4))
                }
                
                Button {
                    todayLog.waterL += 0.25
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("250ml")
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color(red: 6/255, green: 182/255, blue: 212/255).opacity(0.12))
                    .foregroundStyle(Color(red: 6/255, green: 182/255, blue: 212/255))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
    
    // MARK: - Food Quick Search Sheet
    
    private var foodSearchQuickSheet: some View {
        NavigationStack {
            List(FoodItem.database) { food in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.name)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Text("\(Int(food.kcalPer100g)) kcal • P: \(String(format: "%.1f", food.proteinPer100g))g • C: \(String(format: "%.1f", food.carbsPer100g))g")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("per 100g")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Database Alimenti")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        showingFoodSearchSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

