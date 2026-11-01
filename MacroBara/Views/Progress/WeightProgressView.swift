//
//  WeightProgressView.swift
//  MacroBara
//

import SwiftUI
import SwiftData
import Charts

private enum YellowBentoTheme {
    // Sfondo contenitore Bento (Giallo sabbia/crema chiarissimo caldo)
    static let cardBackgroundStart = Color(red: 254/255, green: 247/255, blue: 228/255)
    static let cardBackgroundEnd = Color(red: 250/255, green: 238/255, blue: 206/255)
    static let cardGradient = LinearGradient(
        colors: [cardBackgroundStart, cardBackgroundEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Gradiente continuo per l'area sottesa all'intera curva:
    // Tratto reale (W0..maxActualWeek) ambra scuro caldo, che sfuma dolcemente nel tratto futuro miele dorato (maxActualWeek..maxWeek)
    static func areaGradient(maxWeek: Int, maxActualWeek: Int = 2) -> LinearGradient {
        let maxW = max(3.0, Double(maxWeek))
        let actualRatio = min(0.85, max(0.12, Double(maxActualWeek) / maxW))
        return LinearGradient(
            stops: [
                .init(color: Color(red: 228/255, green: 165/255, blue: 40/255).opacity(0.85), location: 0.0),
                .init(color: Color(red: 228/255, green: 165/255, blue: 40/255).opacity(0.80), location: actualRatio),
                .init(color: Color(red: 242/255, green: 198/255, blue: 85/255).opacity(0.65), location: min(1.0, actualRatio + 0.04)),
                .init(color: Color(red: 248/255, green: 215/255, blue: 110/255).opacity(0.40), location: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // Linea peso effettivo: Giallo ambra scuro, SOLIDA, continua, mai tratteggiata (W0..W2)
    static let actualLine = Color(red: 185/255, green: 115/255, blue: 15/255) // #B9730F
    
    // Linea previsioni future: Giallo dorato caldo, SOLIDA, continua, mai tratteggiata (W2..W6 / W13)
    static let predictionLine = Color(red: 215/255, green: 150/255, blue: 30/255) // #D7961E
    
    // Tipografia ed elementi grafici interni alla card Bento
    static let darkBrownText = Color(red: 74/255, green: 40/255, blue: 5/255) // #4A2805
    static let mutedBrownText = Color(red: 125/255, green: 85/255, blue: 37/255) // #7D5525
    static let badgeBg = Color(red: 242/255, green: 225/255, blue: 182/255)
}

private struct ProgressSegmentedPicker<T: Hashable>: View {
    let items: [(title: String, tag: T)]
    @Binding var selection: T
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.tag) { item in
                let isSelected = selection == item.tag
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selection = item.tag
                    }
                } label: {
                    Text(item.title)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isSelected ? Theme.heroEspressoDark : Color.white.opacity(0.85))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity)
                        .background(
                            isSelected ? Color.white : Color.white.opacity(0.10)
                        )
                        .clipShape(Capsule())
                        .shadow(color: isSelected ? Color.black.opacity(0.18) : Color.clear, radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.28))
        .clipShape(Capsule())
    }
}

struct WeightProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeighIn.weekNumber, order: .forward) private var weighIns: [WeighIn]
    @Query(sort: \DailyLog.date, order: .forward) private var logs: [DailyLog]
    
    @State private var selectedTab: Int = 0
    @State private var trajectoryHorizonTab: Int = 0 // 0: Prossime 6 settimane, 1: Traguardo Normopeso
    @State private var selectedWeekDouble: Double? = 2.0 // Settimana ispezionata interattivamente al tocco (W2 di default)
    @State private var calorieRangeTab: Int = 0      // 0: Ultimi 7 Giorni, 1: Tutto lo Storico
    @State private var calorieChartMode: Int = 0     // 0: Intake vs TDEE (Affiancati), 1: Deficit Netto Giornaliero
    @State private var macroPeriodTab: Int = 0       // 0: Ieri, 1: Ultimi 7 Giorni, 2: Ultimo Mese
    @State private var sugarRangeTab: Int = 0        // 0: Ultimi 7 Giorni, 1: Tutto lo Storico
    @State private var showingAddWeightSheet = false
    @State private var newWeightText = ""
    @State private var newWeightNotes = ""
    @State private var newWeightDate = Date()
    @State private var newWeightWeek = 2
    @State private var showingDeleteWeighInAlert = false
    @State private var weighInToDelete: WeighIn? = nil
    
    private var currentProfile: UserProfile {
        profiles.first ?? UserProfile()
    }
    
    private var deduplicatedWeighIns: [WeighIn] {
        var seen = Set<Int>()
        var result: [WeighIn] = []
        for item in weighIns.sorted(by: { $0.weekNumber < $1.weekNumber }) {
            if !seen.contains(item.weekNumber) {
                seen.insert(item.weekNumber)
                result.append(item)
            }
        }
        return result
    }
    
    private var deduplicatedLogsWithMeals: [DailyLog] {
        var seen = Set<String>()
        var result: [DailyLog] = []
        let valid = logs.filter { $0.totalKcal > 0 }.sorted(by: { $0.date < $1.date })
        for item in valid {
            if !seen.contains(item.dateString) {
                seen.insert(item.dateString)
                result.append(item)
            }
        }
        return result
    }
    
    // MARK: - Modello Traiettoria Peso (Reale vs Stima Deficit vs Proiezione Futura)
    
    struct TrajectoryPoint: Identifiable, Equatable {
        var id: String { label }
        let weekNumber: Int
        let label: String
        let dateLabel: String
        let actual: Double?      // Solo per W0, W1, W2 (Bilancia)
        let estimated: Double?   // Solo per W0, W1, W2 (Stima teorica 7.700 kcal)
        let projected: Double?   // W2 (punto ponte) fino a W6/W13 (Proiezione futura probabile)
        let isTarget: Bool
        let annotationText: String?
        let isToday: Bool
        
        var displayWeight: Double {
            actual ?? projected ?? estimated ?? 87.9
        }
    }
    
    private var maxActualWeek: Int {
        max(0, deduplicatedWeighIns.map(\.weekNumber).max() ?? 0)
    }
    
    private func dateForWeek(_ w: Int) -> Date {
        if let existing = deduplicatedWeighIns.first(where: { $0.weekNumber == w }) {
            return existing.date
        }
        let calendar = Calendar.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 10
        comps.day = 19
        let base = calendar.date(from: comps) ?? Date()
        return calendar.date(byAdding: .day, value: w * 7, to: base) ?? Date()
    }
    
    private func dateLabelForWeek(_ w: Int) -> String {
        let d = dateForWeek(w)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "dd MMM"
        return formatter.string(from: d).capitalized
    }
    
    private func weekNumber(for date: Date) -> Int {
        let calendar = Calendar.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 10
        comps.day = 19
        let base = calendar.date(from: comps) ?? date
        let diffDays = calendar.dateComponents([.day], from: calendar.startOfDay(for: base), to: calendar.startOfDay(for: date)).day ?? 0
        let w = Int(round(Double(diffDays) / 7.0))
        return max(0, w)
    }
    
    private var trajectoryPoints: [TrajectoryPoint] {
        let startW = currentProfile.startWeightKg // 89.0 kg
        let targetNormopeso = currentProfile.normopesoMaxWeightKg // 80.7 kg
        let weighs = deduplicatedWeighIns
        let logsList = deduplicatedLogsWithMeals
        
        var points: [TrajectoryPoint] = []
        let lastActualW = maxActualWeek
        
        // 1. Punti Reali Registrati (W0 ... maxActualWeek)
        var latestActualWeight = startW
        for w in 0...lastActualW {
            let actRecord = weighs.first(where: { $0.weekNumber == w })
            let actVal: Double = actRecord?.weightKg ?? (w == 0 ? startW : latestActualWeight)
            latestActualWeight = actVal
            
            // Calcolo deficit calorico cumulativo fino a questa settimana per la stima teorica
            let daysCovered = max(1, (w + 1) * 7)
            let logsSubset = logsList.prefix(daysCovered)
            let cumDeficit = logsSubset.reduce(0.0) { $0 + max(0, $1.realTdee - $1.totalKcal) }
            let estVal = max(70.0, startW - (cumDeficit / 7700.0))
            
            // Punto ponte: all'ultima settimana reale, projected = actVal per connettere la curva futura
            let projVal: Double? = (w == lastActualW) ? actVal : nil
            let isTodayVal = (w == lastActualW)
            
            points.append(TrajectoryPoint(
                weekNumber: w,
                label: "W\(w)",
                dateLabel: dateLabelForWeek(w),
                actual: actVal,
                estimated: (estVal * 10).rounded() / 10,
                projected: projVal,
                isTarget: false,
                annotationText: String(format: "%.1f", actVal),
                isToday: isTodayVal
            ))
        }
        
        // 2. Punti di Previsione Futura ((maxActualWeek + 1) ... maxWeekNumber)
        let weeklyLossRate = max(0.40, (weeklyAverageDeficitValue * 7.0) / 7700.0)
        var previousProj = latestActualWeight
        
        if (lastActualW + 1) <= maxWeekNumber {
            for w in (lastActualW + 1)...maxWeekNumber {
                let nextProj = max(currentProfile.targetWeightKg, ((previousProj - weeklyLossRate) * 10).rounded() / 10)
                previousProj = nextProj
                let isTarget = (nextProj <= targetNormopeso + 0.1 && nextProj >= targetNormopeso - 0.4) || w == maxWeekNumber
                let anno = isTarget ? "🎯 80.7" : nil
                
                points.append(TrajectoryPoint(
                    weekNumber: w,
                    label: "W\(w)",
                    dateLabel: dateLabelForWeek(w),
                    actual: nil,
                    estimated: nil,
                    projected: nextProj,
                    isTarget: isTarget,
                    annotationText: anno,
                    isToday: false
                ))
            }
        }
        
        return points
    }
    
    private var latestDeltaVsEstimate: Double {
        guard let pt = trajectoryPoints.first(where: { $0.weekNumber == maxActualWeek }),
              let act = pt.actual,
              let est = pt.estimated else { return 0.2 }
        return ((act - est) * 10).rounded() / 10
    }
    
    private var weeklyAverageDeficitValue: Double {
        let recent = deduplicatedLogsWithMeals.suffix(7)
        guard !recent.isEmpty else { return 600.0 }
        let sum = recent.reduce(0.0) { $0 + max(0, $1.realTdee - $1.totalKcal) }
        return max(300.0, sum / Double(recent.count))
    }
    
    private var weeksToGoal: (weeks: Int, targetKg: Double, targetName: String) {
        let curr = currentProfile.currentWeightKg
        let target = currentProfile.targetWeightKg // 80.7 o 78.0
        let targetName = target <= 80.7 ? "Normopeso (80.7 kg)" : "Target (\(String(format: "%.1f", target)) kg)"
        
        let kgToLose = max(0.0, curr - 80.7)
        let weeklyKgLost = (weeklyAverageDeficitValue * 7.0) / 7700.0
        guard weeklyKgLost > 0 else { return (13, 80.7, targetName) }
        let w = Int(ceil(kgToLose / weeklyKgLost))
        return (max(1, w), 80.7, targetName)
    }
    
    private var maxWeekNumber: Int {
        if trajectoryHorizonTab == 0 {
            return max(6, maxActualWeek + 4)
        } else {
            return max(13, max(maxActualWeek + 6, weeksToGoal.weeks))
        }
    }
    
    private var activeWeekNumber: Int {
        if let d = selectedWeekDouble {
            return min(maxWeekNumber, max(0, Int(round(d))))
        }
        return maxActualWeek
    }
    
    private var activePoint: TrajectoryPoint {
        trajectoryPoints.first(where: { $0.weekNumber == activeWeekNumber })
            ?? (trajectoryPoints.first(where: { $0.isToday }) ?? trajectoryPoints[0])
    }
    
    private var chartYDomain: ClosedRange<Double> {
        let weights = trajectoryPoints.map(\.displayWeight)
        guard let minW = weights.min(), let maxW = weights.max() else {
            return 85.0...89.5
        }
        if trajectoryHorizonTab == 0 {
            // Prossime 6 settimane: zoom massimo sui dati reali e previsioni a breve termine
            let lower = floor((minW - 0.4) * 2) / 2.0
            let upper = ceil((maxW + 0.3) * 2) / 2.0
            return lower...upper
        } else {
            // Traguardo Normopeso (verso 80.7)
            let lower = 80.0
            let upper = ceil((maxW + 0.4) * 2) / 2.0
            return lower...upper
        }
    }
    
    private var chartYStride: Double {
        trajectoryHorizonTab == 0 ? 0.5 : 1.0
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // Selettore Principale Sezioni (4 Metriche)
                    ProgressSegmentedPicker(
                        items: [
                            ("Traiettoria", 0),
                            ("Bilancio Kcal", 1),
                            ("Macro", 2),
                            ("Zuccheri", 3)
                        ],
                        selection: $selectedTab
                    )
                    .padding(.horizontal, 4)
                    
                    if selectedTab == 0 {
                        trajectoryWeightSection
                    } else if selectedTab == 1 {
                        calorieBalanceSection
                    } else if selectedTab == 2 {
                        macroBreakdownSection
                    } else {
                        sugarTrackingSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(
                LinearGradient(
                    colors: [
                        Theme.heroEspressoLight,
                        Theme.heroEspressoDark
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Analytics & Progressi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newWeightDate = Date()
                        newWeightWeek = weekNumber(for: newWeightDate)
                        newWeightText = ""
                        newWeightNotes = ""
                        showingAddWeightSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.coralTerracotta)
                    }
                }
            }
            .sheet(isPresented: $showingAddWeightSheet) {
                addWeighInSheet
            }
        }
    }
    
    // MARK: - 1. Sezione Traiettoria Peso (Reale vs Stima vs Proiezione Futura)
    
    private var trajectoryWeightSection: some View {
        VStack(spacing: 16) {
            // KPI Summary Row (Bianchi con testo scuro nitido)
            HStack(spacing: 10) {
                miniStatCard(
                    title: "PESO BILANCIA",
                    value: "\(String(format: "%.1f", currentProfile.currentWeightKg))",
                    unit: "kg",
                    subtitle: "Oggi (W\(maxActualWeek))",
                    color: Theme.coralTerracotta
                )
                
                let latestEst = trajectoryPoints.first(where: { $0.weekNumber == maxActualWeek })?.estimated ?? 87.7
                let diffEst = ((currentProfile.currentWeightKg - latestEst) * 10).rounded() / 10
                miniStatCard(
                    title: "STIMA DEFICIT",
                    value: "\(String(format: "%.1f", latestEst))",
                    unit: "kg",
                    subtitle: "Teorica (\(diffEst >= 0 ? "+\(String(format: "%.1f", diffEst))" : String(format: "%.1f", diffEst)) kg)",
                    color: Color(red: 6/255, green: 182/255, blue: 212/255)
                )
                
                miniStatCard(
                    title: "AL TRAGUARDO",
                    value: "~\(weeksToGoal.weeks)",
                    unit: "sett.",
                    subtitle: "verso 80.7 kg",
                    color: Color(red: 16/255, green: 185/255, blue: 129/255)
                )
            }
            .environment(\.colorScheme, .light)
            
            // Selettore Orizzonte Temporale (2 Opzioni)
            ProgressSegmentedPicker(
                items: [
                    ("Prossime 6 settimane", 0),
                    ("Traguardo Normopeso", 1)
                ],
                selection: $trajectoryHorizonTab
            )
            
            // Forecast Banner Card (Bianca)
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.coralTerracotta.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.coralTerracotta)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Previsione Traiettoria Futura")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("Al ritmo medio di -\(Int(weeklyAverageDeficitValue)) kcal/die (-0.55 kg/sett), raggiungerai il Normopeso (80.7 kg) in ~\(weeksToGoal.weeks) settimane.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 3)
            .environment(\.colorScheme, .light)
            
            // Grafico Traiettoria Peso Bento (Interamente Giallo End-to-End con Previsione Colorata e Zoom Y)
            VStack(spacing: 0) {
                // Sezione Superiore: Header + Ispettore Dinamico + Selettore Settimane
                VStack(alignment: .leading, spacing: 14) {
                    // Header Sezione Bento Style
                    HStack(alignment: .center) {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(YellowBentoTheme.badgeBg)
                                    .frame(width: 36, height: 36)
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(YellowBentoTheme.darkBrownText)
                            }
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Weight")
                                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                                    .foregroundStyle(YellowBentoTheme.darkBrownText)
                                Text("Traiettoria Peso Corporeo")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(YellowBentoTheme.mutedBrownText)
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 11))
                            Text("Scorri")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(YellowBentoTheme.badgeBg.opacity(0.85))
                        .foregroundStyle(YellowBentoTheme.darkBrownText)
                        .clipShape(Capsule())
                    }
                    
                    // Box Ispettore Dinamico
                    inspectorBox(for: activePoint)
                    
                    // Selettore Rapido Orizzontale delle Settimane
                    weekCarouselView(activeWeek: activeWeekNumber)
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 12)
                
                // Grafico End-to-End coi bordi del riquadro, senza box interno!
                Chart {
                    // Linea Target Normopeso se visibile
                    if chartYDomain.contains(80.7) {
                        RuleMark(y: .value("Normopeso", 80.7))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .foregroundStyle(Color(red: 16/255, green: 155/255, blue: 105/255).opacity(0.85))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Normopeso 80.7 kg")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(red: 16/255, green: 155/255, blue: 105/255))
                                    .padding(.trailing, 10)
                            }
                    }
                    
                    // 1. Unica Area Continua Sottesa all'Intera Traiettoria (W0..maxWeek)
                    // Ambra scuro caldo sul peso effettivo (W0..maxActualWeek), che sfuma dolcemente in miele dorato per le previsioni
                    ForEach(trajectoryPoints) { point in
                        AreaMark(
                            x: .value("Settimana", Double(point.weekNumber)),
                            yStart: .value("Base", chartYDomain.lowerBound),
                            yEnd: .value("Peso", point.displayWeight)
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(YellowBentoTheme.areaGradient(maxWeek: maxWeekNumber, maxActualWeek: maxActualWeek))
                    }
                    
                    // 2. Unica Curva Principale Traiettoria Peso (Dati Reali + Previsione Futura Continua)
                    ForEach(trajectoryPoints) { point in
                        LineMark(
                            x: .value("Settimana", Double(point.weekNumber)),
                            y: .value("Peso", point.displayWeight)
                        )
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 3.8, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(YellowBentoTheme.actualLine)
                    }
                    
                    // 3. Punti Interattivi Previsione Futura (Oltre maxActualWeek)
                    ForEach(trajectoryPoints.filter { $0.actual == nil }) { point in
                        PointMark(
                            x: .value("Settimana", Double(point.weekNumber)),
                            y: .value("Peso", point.displayWeight)
                        )
                        .foregroundStyle(YellowBentoTheme.predictionLine)
                        .symbolSize(activeWeekNumber == point.weekNumber ? 60 : (point.isTarget ? 45 : 24))
                        .annotation(position: .top, alignment: point.weekNumber == maxWeekNumber ? .trailing : .center) {
                            if let text = point.annotationText {
                                Text(text)
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(YellowBentoTheme.darkBrownText)
                                    .offset(x: point.weekNumber == maxWeekNumber ? -12 : 0)
                            }
                        }
                    }
                    
                    // 4. Punti Interattivi Peso Effettivo (Primari, grandi e in primo piano, W0..maxActualWeek)
                    ForEach(trajectoryPoints.filter { $0.actual != nil }) { point in
                        PointMark(
                            x: .value("Settimana", Double(point.weekNumber)),
                            y: .value("Peso", point.actual!)
                        )
                        .foregroundStyle(YellowBentoTheme.actualLine)
                        .symbolSize(activeWeekNumber == point.weekNumber ? 95 : 60)
                        .annotation(position: .top, alignment: point.weekNumber == 0 ? .leading : .center) {
                            Text(String(format: "%.1f", point.actual!))
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .foregroundStyle(YellowBentoTheme.darkBrownText)
                                .offset(x: point.weekNumber == 0 ? 12 : 0)
                        }
                    }
                    
                    // 5. Cursore Verticale di Ispezione al Tocco
                    RuleMark(x: .value("Settimana", Double(activeWeekNumber)))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                        .foregroundStyle(YellowBentoTheme.actualLine.opacity(0.85))
                }
                .chartXScale(domain: 0.0 ... Double(maxWeekNumber))
                .chartXSelection(value: $selectedWeekDouble)
                .chartYScale(domain: chartYDomain)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .stride(by: chartYStride)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8, dash: [4, 4]))
                            .foregroundStyle(Color(red: 170/255, green: 130/255, blue: 60/255).opacity(0.25))
                        if let doubleVal = value.as(Double.self) {
                            AxisValueLabel {
                                Text(String(format: "%.1f", doubleVal))
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(YellowBentoTheme.mutedBrownText)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(position: .bottom, values: Array(stride(from: 0, through: maxWeekNumber, by: 1))) { val in
                        if let w = val.as(Int.self) {
                            AxisValueLabel {
                                Text("W\(w)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(YellowBentoTheme.mutedBrownText)
                            }
                        }
                    }
                }
                .frame(height: 270)
                .clipped()
                
                // Sezione Inferiore: Footer Bento + Legenda Chiara a 2 Elementi
                VStack(spacing: 12) {
                    // Valore grande e variazione
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(String(format: "%.1f", currentProfile.currentWeightKg))")
                                .font(.system(size: 32, weight: .heavy, design: .rounded))
                                .foregroundStyle(YellowBentoTheme.darkBrownText)
                            Text("Kilograms")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(YellowBentoTheme.mutedBrownText)
                        }
                        
                        Spacer()
                        
                        let totalLost = currentProfile.currentWeightKg - currentProfile.startWeightKg
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 3) {
                                Image(systemName: totalLost <= 0 ? "arrow.down.right" : "arrow.up.right")
                                    .font(.system(size: 12, weight: .bold))
                                Text(totalLost <= 0 ? "\(String(format: "%.1f", totalLost))" : "+\(String(format: "%.1f", totalLost))")
                                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                            }
                            .foregroundStyle(totalLost <= 0 ? Color(red: 16/255, green: 155/255, blue: 105/255) : YellowBentoTheme.actualLine)
                            
                            Text("Change (W0-W\(maxActualWeek))")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(YellowBentoTheme.mutedBrownText)
                        }
                    }
                    .padding(.top, 4)
                    
                    Divider()
                        .background(YellowBentoTheme.darkBrownText.opacity(0.15))
                    
                    // Legenda Curva Unica: Tratto Reale e Previsione Futura
                    HStack(spacing: 20) {
                        legendPill(color: YellowBentoTheme.actualLine, isDashed: false, isThin: false, label: "Traiettoria Peso (Reale)", textColor: YellowBentoTheme.darkBrownText)
                        legendPill(color: YellowBentoTheme.predictionLine, isDashed: false, isThin: false, label: "Previsione Futura", textColor: YellowBentoTheme.mutedBrownText)
                    }
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
            .background(YellowBentoTheme.cardGradient)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color.black.opacity(0.20), radius: 14, x: 0, y: 6)
            
            // Card Spiegazione Scientifica Differenza Bilancia vs Stima (Bianca)
            let currWVal = currentProfile.currentWeightKg
            let estWVal = trajectoryPoints.first(where: { $0.weekNumber == maxActualWeek })?.estimated ?? 87.7
            let deltaVal = ((currWVal - estWVal) * 10).rounded() / 10
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Theme.coralTerracotta)
                    Text("Come interpretare la differenza tra Bilancia e Stima")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                
                Text("• **Peso Rilevato (\(String(format: "%.1f", currWVal)) kg)**: Misurato la domenica mattina a digiuno. È influenzato da ritenzione idrica, scorte di glicogeno muscolare e idratazione.\n• **Stima da Deficit (\(String(format: "%.1f", estWVal)) kg)**: Calcolo basato sul deficit calorico effettivo (7.700 kcal = 1 kg di grasso puro ossidato).\n• **Delta (\(deltaVal >= 0 ? "+\(String(format: "%.1f", deltaVal))" : String(format: "%.1f", deltaVal)) kg)**: Differenza minima che certifica una perdita di grasso reale e pulita conforme al piano alimentare.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 2)
            .environment(\.colorScheme, .light)
            
            // Storico Pesate Ufficiali (Bianca)
            historyTableCard
                .environment(\.colorScheme, .light)
        }
    }
    
    private var historyTableCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("STORICO PESATE UFFICIALI")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(deduplicatedWeighIns.count) registrate")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            let sorted = deduplicatedWeighIns.sorted(by: { $0.weekNumber > $1.weekNumber })
            ForEach(sorted) { item in
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Settimana \(item.weekNumber)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            if item.deltaPrevKg != 0 {
                                Text(item.deltaPrevKg < 0 ? "\(String(format: "%.1f", item.deltaPrevKg)) kg" : "+\(String(format: "%.1f", item.deltaPrevKg)) kg")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(item.deltaPrevKg <= 0 ? Color(red: 16/255, green: 185/255, blue: 129/255) : Color(red: 244/255, green: 63/255, blue: 94/255))
                            }
                        }
                        
                        HStack(spacing: 6) {
                            let formatter = DateFormatter()
                            let _ = formatter.locale = Locale(identifier: "it_IT")
                            let _ = formatter.dateFormat = "dd MMM yyyy"
                            Text(formatter.string(from: item.date).capitalized)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                            
                            if !item.notes.isEmpty {
                                Text("• \(item.notes)")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Text("\(String(format: "%.1f", item.weightKg)) kg")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .padding(.trailing, 4)
                    
                    Button {
                        weighInToDelete = item
                        showingDeleteWeighInAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(red: 244/255, green: 63/255, blue: 94/255))
                            .frame(width: 32, height: 32)
                            .background(Color(red: 244/255, green: 63/255, blue: 94/255).opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                
                if item.id != sorted.last?.id {
                    Divider()
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
        .environment(\.colorScheme, .light)
        .alert("Eliminare Pesata?", isPresented: $showingDeleteWeighInAlert, presenting: weighInToDelete) { item in
            Button("Elimina", role: .destructive) {
                deleteWeighIn(item)
            }
            Button("Annulla", role: .cancel) {}
        } message: { item in
            Text("Vuoi davvero eliminare la pesata di Settimana \(item.weekNumber) (\(String(format: "%.1f", item.weightKg)) kg)? Il grafico e la traiettoria si ricalcoleranno automaticamente.")
        }
    }
    
    // MARK: - Componenti Grafico Bento
    
    private func inspectorBox(for activePoint: TrajectoryPoint) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(activePoint.actual != nil ? YellowBentoTheme.actualLine : YellowBentoTheme.predictionLine)
                        .frame(width: 8, height: 8)
                    
                    Text("Settimana \(activePoint.weekNumber) • \(activePoint.dateLabel)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(YellowBentoTheme.darkBrownText)
                    
                    if activePoint.isToday {
                        Text("OGGI")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(YellowBentoTheme.actualLine.opacity(0.18))
                            .foregroundStyle(YellowBentoTheme.actualLine)
                            .clipShape(Capsule())
                    } else if activePoint.isTarget {
                        Text("NORMOPESO")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(red: 16/255, green: 155/255, blue: 105/255).opacity(0.18))
                            .foregroundStyle(Color(red: 16/255, green: 155/255, blue: 105/255))
                            .clipShape(Capsule())
                    } else if activePoint.actual != nil {
                        Text("RILEVATO")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(YellowBentoTheme.darkBrownText.opacity(0.12))
                            .foregroundStyle(YellowBentoTheme.darkBrownText)
                            .clipShape(Capsule())
                    } else {
                        Text("PREVISIONE")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(YellowBentoTheme.predictionLine.opacity(0.18))
                            .foregroundStyle(YellowBentoTheme.predictionLine)
                            .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: "%.1f", activePoint.displayWeight))
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(activePoint.actual != nil ? YellowBentoTheme.actualLine : YellowBentoTheme.darkBrownText)
                    Text("kg")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(YellowBentoTheme.mutedBrownText)
                }
            }
            
            HStack(spacing: 12) {
                if let act = activePoint.actual {
                    HStack(spacing: 4) {
                        Text("Bilancia:")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(YellowBentoTheme.mutedBrownText)
                        Text("\(String(format: "%.1f", act)) kg")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(YellowBentoTheme.actualLine)
                    }
                }
                
                if let est = activePoint.estimated {
                    HStack(spacing: 4) {
                        Text("Stima:")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(YellowBentoTheme.mutedBrownText)
                        Text("\(String(format: "%.1f", est)) kg")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(YellowBentoTheme.mutedBrownText)
                    }
                    
                    if let act = activePoint.actual {
                        let delta = ((act - est) * 10).rounded() / 10
                        Text("Delta: \(delta >= 0 ? "+\(String(format: "%.1f", delta))" : String(format: "%.1f", delta)) kg")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(abs(delta) <= 0.3 ? Color(red: 16/255, green: 155/255, blue: 105/255) : YellowBentoTheme.actualLine)
                    }
                } else if let proj = activePoint.projected {
                    let diffFromToday = ((proj - currentProfile.currentWeightKg) * 10).rounded() / 10
                    HStack(spacing: 4) {
                        Text("Da oggi:")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(YellowBentoTheme.mutedBrownText)
                        Text("\(diffFromToday >= 0 ? "+\(String(format: "%.1f", diffFromToday))" : String(format: "%.1f", diffFromToday)) kg")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 16/255, green: 155/255, blue: 105/255))
                    }
                    
                    let distNormo = max(0, ((proj - 80.7) * 10).rounded() / 10)
                    if distNormo > 0 {
                        Text("(\(String(format: "%.1f", distNormo)) kg al Normopeso)")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(YellowBentoTheme.mutedBrownText)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private func weekCarouselView(activeWeek: Int) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(trajectoryPoints) { pt in
                        let isSelected = activeWeek == pt.weekNumber
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                selectedWeekDouble = Double(pt.weekNumber)
                            }
                        } label: {
                            VStack(spacing: 3) {
                                Text(pt.label)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                Text(pt.dateLabel)
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                Text(String(format: "%.1f", pt.displayWeight))
                                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(
                                isSelected
                                    ? YellowBentoTheme.actualLine
                                    : (pt.isToday ? YellowBentoTheme.badgeBg : Color.white.opacity(0.65))
                            )
                            .foregroundStyle(isSelected ? Color.white : (pt.isToday ? YellowBentoTheme.actualLine : YellowBentoTheme.darkBrownText))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(isSelected ? Color.white.opacity(0.5) : (pt.isTarget ? Color(red: 16/255, green: 155/255, blue: 105/255) : Color.clear), lineWidth: 1.2)
                            )
                        }
                        .buttonStyle(.plain)
                        .id(pt.weekNumber)
                    }
                }
                .padding(.horizontal, 2)
            }
            .onChange(of: selectedWeekDouble) { _, newDouble in
                if let d = newDouble {
                    withAnimation {
                        proxy.scrollTo(Int(round(d)), anchor: .center)
                    }
                }
            }
        }
    }
    
    // MARK: - 2. Sezione Bilancio Energetico
    
    private var calorieBalanceSection: some View {
        VStack(spacing: 16) {
            // Selettore Range Temporale (Tutto lo Storico vs Ultimi 7 Giorni)
            ProgressSegmentedPicker(
                items: [
                    ("Ultimi 7 Giorni", 0),
                    ("Tutto lo Storico", 1)
                ],
                selection: $calorieRangeTab
            )
            
            // Selettore Modalità Grafico (Affiancato vs Deficit Netto)
            ProgressSegmentedPicker(
                items: [
                    ("Intake vs Spesa TDEE", 0),
                    ("Deficit Netto Giornaliero", 1)
                ],
                selection: $calorieChartMode
            )
            
            // Deficit Medio Settimanale in evidenza
            HStack(spacing: 12) {
                miniStatCard(
                    title: "DEFICIT MEDIO",
                    value: "-\(Int(weeklyAverageDeficitValue))",
                    unit: "kcal/die",
                    subtitle: "Ultima settimana",
                    color: Color(red: 16/255, green: 185/255, blue: 129/255)
                )
                
                let fatLostWeek = ((weeklyAverageDeficitValue * 7.0) / 7700.0 * 100).rounded() / 100
                miniStatCard(
                    title: "GRASSO OSSIDATO",
                    value: "~\(String(format: "%.2f", fatLostWeek))",
                    unit: "kg",
                    subtitle: "Stima su 7 giorni",
                    color: Theme.coralTerracotta
                )
            }
            
            let displayLogs = calorieRangeTab == 0 ? Array(deduplicatedLogsWithMeals.suffix(7)) : deduplicatedLogsWithMeals
            
            // Grafico Bilancio Energetico Senza Incroci
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(calorieChartMode == 0 ? "CALORIE ASSUNTE VS SPESA TDEE (BARRE AFFIANCATE)" : "DEFICIT NETTO GIORNALIERO (LIPOLISI)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(calorieChartMode == 0 ?
                         "Barre affiancate separate: arancione (intake) e ciano (TDEE). Nessun incrocio di linee." :
                         "Deficit calorico netto giornaliero generato rispetto al TDEE reale Apple Watch.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                if calorieChartMode == 0 {
                    // Modalità 0: Barre Affiancate Side-by-Side (Intake vs TDEE)
                    Chart {
                        // Linea Target 1600 kcal
                        RuleMark(y: .value("Target", currentProfile.targetKcal))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .foregroundStyle(Color(red: 245/255, green: 158/255, blue: 11/255).opacity(0.85))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Target 1600 kcal")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(red: 245/255, green: 158/255, blue: 11/255))
                            }
                        
                        ForEach(displayLogs) { item in
                            // Barra 1: Calorie Assunte (Intake)
                            BarMark(
                                x: .value("Data", shortDate(item.dateString)),
                                y: .value("Kcal", item.totalKcal)
                            )
                            .foregroundStyle(Theme.coralTerracotta)
                            .position(by: .value("Tipo", "Assunte (Intake)"))
                            .cornerRadius(4)
                            
                            // Barra 2: Spesa Energetica Totale (TDEE Apple Watch)
                            BarMark(
                                x: .value("Data", shortDate(item.dateString)),
                                y: .value("Kcal", item.realTdee)
                            )
                            .foregroundStyle(Color(red: 6/255, green: 182/255, blue: 212/255))
                            .position(by: .value("Tipo", "Spesa TDEE"))
                            .cornerRadius(4)
                        }
                    }
                    .chartYScale(domain: 0...2600)
                    .frame(height: 230)
                    .clipped()
                    
                    // Legenda Chiara
                    HStack(spacing: 14) {
                        legendPill(color: Theme.coralTerracotta, isDashed: false, label: "Calorie Assunte (Intake)")
                        legendPill(color: Color(red: 6/255, green: 182/255, blue: 212/255), isDashed: false, label: "Spesa TDEE")
                        legendPill(color: Color(red: 245/255, green: 158/255, blue: 11/255), isDashed: true, label: "Target (1600)")
                    }
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                } else {
                    // Modalità 1: Deficit Netto Giornaliero
                    Chart {
                        // Linea Target Deficit Ottimale a -500 kcal
                        RuleMark(y: .value("Deficit Ideale", 500))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .foregroundStyle(Color(red: 16/255, green: 185/255, blue: 129/255).opacity(0.85))
                            .annotation(position: .top, alignment: .trailing) {
                                Text("Target Deficit 500 kcal")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(red: 16/255, green: 185/255, blue: 129/255))
                            }
                        
                        ForEach(displayLogs) { item in
                            let def = max(0, item.realTdee - item.totalKcal)
                            BarMark(
                                x: .value("Data", shortDate(item.dateString)),
                                y: .value("Deficit", def)
                            )
                            .foregroundStyle(
                                def >= 450 ?
                                    Color(red: 16/255, green: 185/255, blue: 129/255) :
                                    Color(red: 245/255, green: 158/255, blue: 11/255)
                            )
                            .cornerRadius(5)
                            .annotation(position: .top) {
                                if def > 0 {
                                    Text("-\(Int(def))")
                                        .font(.system(size: 8, weight: .bold, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .chartYScale(domain: 0...1200)
                    .frame(height: 230)
                    .clipped()
                    
                    // Legenda Deficit
                    HStack(spacing: 14) {
                        legendPill(color: Color(red: 16/255, green: 185/255, blue: 129/255), isDashed: false, label: "Deficit Efficace (≥450 kcal)")
                        legendPill(color: Color(red: 245/255, green: 158/255, blue: 11/255), isDashed: false, label: "Deficit Moderato")
                        legendPill(color: Color(red: 16/255, green: 185/255, blue: 129/255), isDashed: true, label: "Target (500)")
                    }
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                }
            }
            .padding(18)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
            .environment(\.colorScheme, .light)
        }
    }
    
    // MARK: - 3. Sezione Ripartizione Macronutrienti (Ieri / Ultima Settimana / Ultimo Mese)
    
    private var macroBreakdownSection: some View {
        VStack(spacing: 16) {
            // Selettore Temporale [Ieri | Ultimi 7 Giorni | Ultimo Mese]
            ProgressSegmentedPicker(
                items: [
                    ("Ieri", 0),
                    ("Ultimi 7 Giorni", 1),
                    ("Ultimo Mese", 2)
                ],
                selection: $macroPeriodTab
            )
            
            let stats = macroStats(for: macroPeriodTab)
            
            // Card Ripartizione Nutrizionale
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("RIPARTIZIONE CALORICA DEI MACRO")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                        Text("Media \(stats.periodTitle) • \(Int(stats.avgKcal)) kcal/die")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    Spacer()
                }
                
                // Barra Percentuale a Segmenti Multipli
                GeometryReader { geo in
                    HStack(spacing: 3) {
                        // Proteine
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 16/255, green: 185/255, blue: 129/255))
                            .frame(width: max(4, geo.size.width * CGFloat(stats.proPct / 100.0)))
                        
                        // Carboidrati
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 245/255, green: 158/255, blue: 11/255))
                            .frame(width: max(4, geo.size.width * CGFloat(stats.carbPct / 100.0)))
                        
                        // Grassi
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(red: 244/255, green: 63/255, blue: 94/255))
                            .frame(width: max(4, geo.size.width * CGFloat(stats.fatPct / 100.0)))
                    }
                }
                .frame(height: 16)
                
                // Dettaglio dei 3 Macro
                VStack(spacing: 12) {
                    macroDetailRow(
                        title: "Proteine Nobili",
                        grams: stats.avgPro,
                        target: currentProfile.targetProteinG,
                        pctOfCalories: stats.proPct,
                        color: Color(red: 16/255, green: 185/255, blue: 129/255),
                        note: "Supporto massa magra e sazietà"
                    )
                    
                    Divider()
                    
                    macroDetailRow(
                        title: "Carboidrati Complessi",
                        grams: stats.avgCarb,
                        target: currentProfile.targetCarbsG,
                        pctOfCalories: stats.carbPct,
                        color: Color(red: 245/255, green: 158/255, blue: 11/255),
                        note: "Energia da avena e cereali integrali"
                    )
                    
                    Divider()
                    
                    macroDetailRow(
                        title: "Lipidi / Grassi",
                        grams: stats.avgFat,
                        target: currentProfile.targetFatG,
                        pctOfCalories: stats.fatPct,
                        color: Color(red: 244/255, green: 63/255, blue: 94/255),
                        note: "Max 50g • Densità 9 kcal/g"
                    )
                }
            }
            .padding(18)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
            .environment(\.colorScheme, .light)
        }
    }
    
    private struct MacroStatsResult {
        var periodTitle: String
        var avgKcal: Double
        var avgPro: Double
        var avgCarb: Double
        var avgFat: Double
        var proPct: Double
        var carbPct: Double
        var fatPct: Double
    }
    
    private func macroStats(for period: Int) -> MacroStatsResult {
        let valid = deduplicatedLogsWithMeals
        let logsSlice: [DailyLog]
        let title: String
        
        switch period {
        case 0:
            title = "Ieri"
            logsSlice = valid.count >= 2 ? [valid[valid.count - 2]] : Array(valid.suffix(1))
        case 1:
            title = "Ultimi 7 Giorni"
            logsSlice = Array(valid.suffix(7))
        default:
            title = "Ultimo Mese"
            logsSlice = Array(valid.suffix(30))
        }
        
        guard !logsSlice.isEmpty else {
            return MacroStatsResult(periodTitle: title, avgKcal: 1600, avgPro: 125, avgCarb: 165, avgFat: 48, proPct: 31, carbPct: 41, fatPct: 27)
        }
        
        let count = Double(logsSlice.count)
        let totalKcal = logsSlice.map(\.totalKcal).reduce(0, +) / count
        let totalPro = logsSlice.map(\.totalProtein).reduce(0, +) / count
        let totalCarb = logsSlice.map(\.totalCarbs).reduce(0, +) / count
        let totalFat = logsSlice.map(\.totalFat).reduce(0, +) / count
        
        let proKcal = totalPro * 4.0
        let carbKcal = totalCarb * 4.0
        let fatKcal = totalFat * 9.0
        let sumKcal = max(1.0, proKcal + carbKcal + fatKcal)
        
        return MacroStatsResult(
            periodTitle: title,
            avgKcal: totalKcal.rounded(),
            avgPro: (totalPro * 10).rounded() / 10,
            avgCarb: (totalCarb * 10).rounded() / 10,
            avgFat: (totalFat * 10).rounded() / 10,
            proPct: (proKcal / sumKcal * 100).rounded(),
            carbPct: (carbKcal / sumKcal * 100).rounded(),
            fatPct: (fatKcal / sumKcal * 100).rounded()
        )
    }
    
    private func macroDetailRow(title: String, grams: Double, target: Double, pctOfCalories: Double, color: Color, note: String) -> some View {
        HStack(alignment: .center) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text(note)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Int(grams))g")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                    Text("/ \(Int(target))g")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Text("\(Int(pctOfCalories))% calorie")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
            }
        }
    }
    
    // MARK: - 4. Sezione Zuccheri Semplici
    
    private var sugarTrackingSection: some View {
        VStack(spacing: 16) {
            // Selettore Range Temporale (Ultimi 7 Giorni vs Tutto lo Storico)
            ProgressSegmentedPicker(
                items: [
                    ("Ultimi 7 Giorni", 0),
                    ("Tutto lo Storico", 1)
                ],
                selection: $sugarRangeTab
            )
            
            let displaySugarLogs = sugarRangeTab == 0 ? Array(deduplicatedLogsWithMeals.suffix(7)) : deduplicatedLogsWithMeals
            let maxSugarInDisplay = displaySugarLogs.map(\.totalSugars).max() ?? 40.0
            // Scala Y dinamica con 25% di respiro superiore: mai più overflow sopra il grafico!
            let sugarYMax = max(55.0, ceil((maxSugarInDisplay * 1.25) / 10.0) * 10.0)
            let conformDays = displaySugarLogs.filter { $0.totalSugars <= 40 }.count
            let totalDays = max(1, displaySugarLogs.count)
            let avgSugar = displaySugarLogs.isEmpty ? 0 : (displaySugarLogs.map(\.totalSugars).reduce(0, +) / Double(displaySugarLogs.count))
            
            HStack(spacing: 12) {
                miniStatCard(
                    title: "SOGLIA SICUREZZA",
                    value: "40",
                    unit: "g/die",
                    subtitle: "Target Metabolico",
                    color: Color(red: 16/255, green: 185/255, blue: 129/255)
                )
                
                miniStatCard(
                    title: "MEDIA PERIODO",
                    value: "\(Int(avgSugar))",
                    unit: "g/die",
                    subtitle: avgSugar <= 40 ? "Ottimale per lipolisi" : "Attenzione picchi",
                    color: avgSugar <= 40 ? Color(red: 16/255, green: 185/255, blue: 129/255) : Color(red: 244/255, green: 63/255, blue: 94/255)
                )
                
                miniStatCard(
                    title: "CONFORMITÀ",
                    value: "\(conformDays)/\(totalDays)",
                    unit: "gg",
                    subtitle: "\(Int(Double(conformDays)/Double(totalDays)*100))% giorni OK",
                    color: Theme.coralTerracotta
                )
            }
            
            // Grafico Andamento Zuccheri con Scala Dinamica e Zero Sovrapposizioni
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("MONITORAGGIO ZUCCHERI SEMPLICI")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("Soglia limite a 40g/die per prevenire picchi insulinici e favorire l'ossidazione lipidica.")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                Chart {
                    // Linea Limite Rosso Tratteggiato a 40g (Soglia Massima)
                    RuleMark(y: .value("Soglia Sicurezza", 40.0))
                        .lineStyle(StrokeStyle(lineWidth: 1.8, dash: [4, 4]))
                        .foregroundStyle(Color(red: 244/255, green: 63/255, blue: 94/255))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("Max 40g/die")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(red: 244/255, green: 63/255, blue: 94/255))
                        }
                    
                    ForEach(displaySugarLogs) { item in
                        BarMark(
                            x: .value("Data", shortDate(item.dateString)),
                            y: .value("Zuccheri", item.totalSugars)
                        )
                        .foregroundStyle(
                            item.totalSugars <= 40 ?
                                Color(red: 16/255, green: 185/255, blue: 129/255) :
                                Color(red: 244/255, green: 63/255, blue: 94/255)
                        )
                        .cornerRadius(5)
                        .annotation(position: .top) {
                            if item.totalSugars > 40 {
                                Text("\(Int(item.totalSugars))g")
                                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Color(red: 244/255, green: 63/255, blue: 94/255))
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...sugarYMax)
                .frame(height: 230)
                .clipped()
                
                HStack(spacing: 16) {
                    legendPill(color: Color(red: 16/255, green: 185/255, blue: 129/255), isDashed: false, label: "Sotto soglia (≤40g)")
                    legendPill(color: Color(red: 244/255, green: 63/255, blue: 94/255), isDashed: false, label: "Sopra soglia (>40g)")
                    legendPill(color: Color(red: 244/255, green: 63/255, blue: 94/255), isDashed: true, label: "Limite 40g")
                }
                .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .padding(18)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
            .environment(\.colorScheme, .light)
            
            // Tips Metabolici Zuccheri
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "heart.text.square.fill")
                        .foregroundStyle(Color(red: 244/255, green: 63/255, blue: 94/255))
                    Text("Impatto Metabolico del Controllo Zuccheri")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                
                Text("Mantenere gli zuccheri semplici sotto i 40g al giorno garantisce una bassa secrezione insulinica post-prandiale, permettendo al glucagone di mobilitare costantemente i depositi adiposi per tutto l'arco della giornata.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 2)
            .environment(\.colorScheme, .light)
        }
    }
    
    // MARK: - Helper Views & Functions
    
    private func miniStatCard(title: String, value: String, unit: String, subtitle: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(color)
                Text(unit)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            Text(subtitle)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
        .environment(\.colorScheme, .light)
    }
    
    private func legendPill(color: Color, isDashed: Bool, isThin: Bool = false, label: String, textColor: Color = .secondary) -> some View {
        HStack(spacing: 5) {
            if isDashed {
                Rectangle()
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                    .frame(width: 14, height: 1.5)
            } else if isThin {
                Capsule()
                    .fill(color)
                    .frame(width: 14, height: 2.2)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            Text(label)
                .foregroundStyle(textColor)
        }
    }
    
    private func shortDate(_ str: String) -> String {
        let parts = str.split(separator: "-")
        if parts.count == 3 {
            return "\(parts[2])/\(parts[1])"
        }
        return str
    }
    
    private var addWeighInSheet: some View {
        NavigationStack {
            Form {
                Section("Dati Pesata") {
                    HStack {
                        Text("Peso Corporeo")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                        Spacer()
                        TextField("87.5", text: $newWeightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(maxWidth: 100)
                        Text("kg")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    
                    DatePicker(
                        "Data Misurazione",
                        selection: $newWeightDate,
                        displayedComponents: [.date]
                    )
                    .environment(\.locale, Locale(identifier: "it_IT"))
                    .onChange(of: newWeightDate) { _, newDate in
                        newWeightWeek = weekNumber(for: newDate)
                    }
                    
                    Stepper("Settimana W\(newWeightWeek)", value: $newWeightWeek, in: 0...52)
                }
                
                Section("Note (Opzionale)") {
                    TextField("Note (es. Check-in domenica mattina)", text: $newWeightNotes)
                }
            }
            .navigationTitle("Registra Peso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { showingAddWeightSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveNewWeighIn()
                    }
                    .bold()
                    .disabled(Double(newWeightText.replacingOccurrences(of: ",", with: ".")) == nil)
                }
            }
        }
    }
    
    private func saveNewWeighIn() {
        guard let w = Double(newWeightText.replacingOccurrences(of: ",", with: ".")) else { return }
        
        // Se esiste già una pesata registrata per questa settimana, la aggiorniamo
        if let existing = deduplicatedWeighIns.first(where: { $0.weekNumber == newWeightWeek }) {
            existing.weightKg = w
            existing.date = newWeightDate
            if !newWeightNotes.isEmpty {
                existing.notes = newWeightNotes
            }
        } else {
            let newEntry = WeighIn(
                weekNumber: newWeightWeek,
                date: newWeightDate,
                weightKg: w,
                notes: newWeightNotes.isEmpty ? "Check-in settimanale" : newWeightNotes
            )
            modelContext.insert(newEntry)
        }
        
        recalculateWeighInsDeltas()
        
        // Aggiorna peso profilo con la pesata reale più recente
        let allWeighs = deduplicatedWeighIns
        let highest = allWeighs.max(by: { $0.weekNumber < $1.weekNumber })
        currentProfile.currentWeightKg = highest?.weightKg ?? w
        
        try? modelContext.save()
        selectedWeekDouble = Double(newWeightWeek)
        showingAddWeightSheet = false
        newWeightText = ""
        newWeightNotes = ""
    }
    
    private func recalculateWeighInsDeltas() {
        let sorted = deduplicatedWeighIns.sorted(by: { $0.weekNumber < $1.weekNumber })
        guard let first = sorted.first else { return }
        var prevWeight = first.weightKg
        for item in sorted {
            if item.weekNumber == first.weekNumber {
                item.deltaPrevKg = 0.0
                item.deltaTotalKg = 0.0
            } else {
                item.deltaPrevKg = ((item.weightKg - prevWeight) * 10).rounded() / 10
                item.deltaTotalKg = ((item.weightKg - first.weightKg) * 10).rounded() / 10
            }
            prevWeight = item.weightKg
        }
    }
    
    private func deleteWeighIn(_ item: WeighIn) {
        modelContext.delete(item)
        try? modelContext.save()
        
        recalculateWeighInsDeltas()
        
        let remaining = deduplicatedWeighIns.filter { $0.id != item.id }
        if let latest = remaining.max(by: { $0.weekNumber < $1.weekNumber }) {
            currentProfile.currentWeightKg = latest.weightKg
            selectedWeekDouble = Double(latest.weekNumber)
        } else {
            currentProfile.currentWeightKg = currentProfile.startWeightKg
            selectedWeekDouble = 0
        }
        
        try? modelContext.save()
    }
}
