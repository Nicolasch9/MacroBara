//
//  MacroBaraWidget.swift
//  MacroBaraWidgetExtension
//

import WidgetKit
import SwiftUI

// MARK: - Design System Widget (Stile Coerente con MacroBara Hero Espresso)

enum WidgetTheme {
    static let heroEspressoDark = Color(red: 24/255, green: 16/255, blue: 14/255)
    static let heroEspressoLight = Color(red: 48/255, green: 32/255, blue: 27/255)
    static let coralTerracotta = Color(red: 232/255, green: 105/255, blue: 75/255)
    static let coralTerracottaLight = Color(red: 252/255, green: 238/255, blue: 234/255)
    static let accentEmerald = Color(red: 16/255, green: 185/255, blue: 129/255)
    static let accentCyan = Color(red: 2/255, green: 132/255, blue: 199/255)
    static let accentRose = Color(red: 244/255, green: 63/255, blue: 94/255)
    static let accentAmber = Color(red: 245/255, green: 158/255, blue: 11/255)
    static let accentOrange = Color(red: 249/255, green: 115/255, blue: 22/255)
    
    static let heroGradient = LinearGradient(
        colors: [heroEspressoLight, heroEspressoDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static func colorsForGrade(_ grade: String) -> (bg: Color, text: Color) {
        if grade.contains("A") {
            return (accentEmerald.opacity(0.24), accentEmerald)
        } else if grade.contains("B") {
            return (accentCyan.opacity(0.24), accentCyan)
        } else if grade.contains("C") {
            // C: voto discreto/sufficiente -> Giallo Ambra ben distinto dal verde delle A
            return (accentAmber.opacity(0.26), accentAmber)
        } else if grade.contains("D") {
            return (accentOrange.opacity(0.26), accentOrange)
        } else {
            return (accentRose.opacity(0.26), accentRose)
        }
    }
}

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), data: WidgetDataModel.currentData())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), data: WidgetDataModel.currentData())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        let entry = SimpleEntry(date: Date(), data: WidgetDataModel.currentData())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let data: WidgetDataModel
}

// MARK: - Modello Dati Widget

struct WidgetDataModel: Codable {
    var greeting: String
    var todayKcal: Int
    var targetKcal: Int
    var kcalRemaining: Int
    var percentTarget: Int
    var todayDeficitKcal: Int
    var proteinG: Double
    var targetProteinG: Double
    var sugarsG: Double
    var maxSugarsG: Double
    var steps: Int
    var targetSteps: Int
    var totalDeficitKcal: Int
    var fatBurnedKg: Double
    var weekGrade: String
    
    struct DayItem: Codable, Identifiable {
        var id: String { date + day }
        var date: String
        var day: String
        var grade: String
        var colorHex: String
        var isToday: Bool
        var isLogged: Bool
    }
    var dayGrades: [DayItem]
    
    static var sampleData: WidgetDataModel {
        WidgetDataModel(
            greeting: greetingForCurrentHour(),
            todayKcal: 1597,
            targetKcal: 1600,
            kcalRemaining: 3,
            percentTarget: 99,
            todayDeficitKcal: -553,
            proteinG: 107.6,
            targetProteinG: 130.0,
            sugarsG: 29.0,
            maxSugarsG: 40.0,
            steps: 4517,
            targetSteps: 7500,
            totalDeficitKcal: -4102,
            fatBurnedKg: 0.53,
            weekGrade: "A+",
            dayGrades: [
                DayItem(date: "2026-10-26", day: "L", grade: "C", colorHex: "F59E0B", isToday: false, isLogged: true),
                DayItem(date: "2026-10-27", day: "M", grade: "A+", colorHex: "10B981", isToday: false, isLogged: true),
                DayItem(date: "2026-10-28", day: "M", grade: "A++", colorHex: "10B981", isToday: false, isLogged: true),
                DayItem(date: "2026-10-29", day: "G", grade: "A+", colorHex: "10B981", isToday: false, isLogged: true),
                DayItem(date: "2026-10-30", day: "V", grade: "A++", colorHex: "10B981", isToday: false, isLogged: true),
                DayItem(date: "2026-10-31", day: "S", grade: "A+", colorHex: "10B981", isToday: false, isLogged: true),
                DayItem(date: "2026-11-01", day: "D", grade: "A", colorHex: "10B981", isToday: true, isLogged: true)
            ]
        )
    }
    
    static func greetingForCurrentHour() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Buongiorno, Marco"
        } else if hour < 18 {
            return "Buon pomeriggio, Marco"
        } else {
            return "Buonasera, Marco"
        }
    }
    
    static func currentData() -> WidgetDataModel {
        if let data = embeddedJSON.data(using: .utf8),
           let parsed = parseJSON(data) {
            return parsed
        }
        return sampleData
    }
    
    static func parseJSON(_ data: Data) -> WidgetDataModel? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        let targetKcal = (json["target_kcal"] as? Int) ?? 1600
        let targetProtein = (json["target_protein"] as? Double) ?? 130.0
        let targetSugars = (json["target_sugars"] as? Double) ?? 40.0
        let targetSteps = (json["target_steps"] as? Int) ?? 7500
        let totalDeficit = Int((json["total_deficit"] as? Double) ?? -4102.0)
        let fatLoss = (json["est_fat_loss_kg"] as? Double) ?? 0.53
        let weekGrade = (json["week_grade"] as? String) ?? "A+"
        
        var todayKcal = 1597
        var todayProtein = 107.6
        var todaySugars = 29.0
        var todaySteps = 0
        var todayDeficit = -553
        
        if let todayDict = json["today"] as? [String: Any] {
            todayKcal = Int((todayDict["kcal"] as? Double) ?? Double(todayKcal))
            todayProtein = (todayDict["protein"] as? Double) ?? todayProtein
            todaySugars = (todayDict["sugars"] as? Double) ?? todaySugars
            todaySteps = (todayDict["steps"] as? Int) ?? todaySteps
            if let defVal = todayDict["deficit"] as? Double {
                todayDeficit = Int(defVal)
            }
        }
        
        let remaining = max(0, targetKcal - todayKcal)
        let percent = targetKcal > 0 ? Int((Double(todayKcal) / Double(targetKcal)) * 100) : 100
        
        var dayItems: [DayItem] = []
        if let daysArray = json["days"] as? [[String: Any]] {
            for d in daysArray {
                let dDate = (d["date"] as? String) ?? ""
                let dInitial = (d["day_initial"] as? String) ?? ""
                let dGrade = (d["grade"] as? String) ?? "A"
                let isToday = (d["is_today"] as? Bool) ?? false
                let isLogged = (d["is_logged"] as? Bool) ?? true
                let colorHex = dGrade.contains("A") ? "10B981" : (dGrade.contains("B") ? "0284C7" : (dGrade.contains("C") ? "F59E0B" : "F43F5E"))
                
                dayItems.append(DayItem(
                    date: dDate,
                    day: dInitial,
                    grade: dGrade,
                    colorHex: colorHex,
                    isToday: isToday,
                    isLogged: isLogged
                ))
            }
        }
        
        return WidgetDataModel(
            greeting: greetingForCurrentHour(),
            todayKcal: todayKcal,
            targetKcal: targetKcal,
            kcalRemaining: remaining,
            percentTarget: percent,
            todayDeficitKcal: todayDeficit,
            proteinG: todayProtein,
            targetProteinG: targetProtein,
            sugarsG: todaySugars,
            maxSugarsG: targetSugars,
            steps: todaySteps > 0 ? todaySteps : ((json["avg_steps"] as? Int) ?? 4517),
            targetSteps: targetSteps,
            totalDeficitKcal: totalDeficit,
            fatBurnedKg: fatLoss,
            weekGrade: weekGrade,
            dayGrades: dayItems.isEmpty ? sampleData.dayGrades : dayItems
        )
    }
    
    static let embeddedJSON: String = #"""
{
  "mode": "weekly",
  "week_label": "Settimana 2 (26/10 - 01/11)",
  "week_number": 2,
  "logged_days": 7,
  "total_days": 7,
  "progress_str": "7/7 giorni",
  "week_grade": "A+",
  "week_score": 80,
  "total_deficit": -4102.2,
  "avg_deficit": -586.0,
  "est_fat_loss_kg": 0.53,
  "total_kcal": 11171.0,
  "avg_kcal": 1595.9,
  "target_kcal": 1600,
  "avg_tdee": 2181.9,
  "avg_sugars": 31.4,
  "target_sugars": 40.0,
  "sugars_safe_days": "6/7",
  "avg_protein": 108.3,
  "target_protein": 130,
  "total_steps": 31622,
  "avg_steps": 4517,
  "target_steps": 7500,
  "weight": 87.9,
  "normoweight": 80.7,
  "distance_normoweight": 7.2,
  "days": [
    {
      "date": "2026-10-26",
      "day_initial": "L",
      "day_name": "Lun",
      "is_today": false,
      "is_logged": true,
      "kcal": 1428,
      "deficit": -873,
      "grade": "C",
      "score": 55,
      "sugars": 59.7,
      "protein": 66.0,
      "steps": 6733
    },
    {
      "date": "2026-10-27",
      "day_initial": "M",
      "day_name": "Mar",
      "is_today": false,
      "is_logged": true,
      "kcal": 1876,
      "deficit": -333,
      "grade": "A+",
      "score": 80,
      "sugars": 27.2,
      "protein": 124.3,
      "steps": 3292
    },
    {
      "date": "2026-10-28",
      "day_initial": "M",
      "day_name": "Mer",
      "is_today": false,
      "is_logged": true,
      "kcal": 1377,
      "deficit": -744,
      "grade": "A++",
      "score": 89,
      "sugars": 20.0,
      "protein": 103.1,
      "steps": 5009
    },
    {
      "date": "2026-10-29",
      "day_initial": "G",
      "day_name": "Gio",
      "is_today": false,
      "is_logged": true,
      "kcal": 1525,
      "deficit": -710,
      "grade": "A+",
      "score": 84,
      "sugars": 35.0,
      "protein": 106.0,
      "steps": 4532
    },
    {
      "date": "2026-10-30",
      "day_initial": "V",
      "day_name": "Ven",
      "is_today": false,
      "is_logged": true,
      "kcal": 1356,
      "deficit": -739,
      "grade": "A++",
      "score": 89,
      "sugars": 17.0,
      "protein": 122.8,
      "steps": 2990
    },
    {
      "date": "2026-10-31",
      "day_initial": "S",
      "day_name": "Sab",
      "is_today": false,
      "is_logged": true,
      "kcal": 2012,
      "deficit": -150,
      "grade": "A+",
      "score": 87,
      "sugars": 32.1,
      "protein": 128.1,
      "steps": 9066
    },
    {
      "date": "2026-11-01",
      "day_initial": "D",
      "day_name": "Dom",
      "is_today": true,
      "is_logged": true,
      "kcal": 1597,
      "deficit": -553,
      "grade": "A",
      "score": 76,
      "sugars": 29.0,
      "protein": 107.6,
      "steps": 0
    }
  ],
  "today": {
    "date": "2026-11-01",
    "weekday": "Domenica",
    "grade": "A",
    "score": 76,
    "kcal": 1597.0,
    "deficit": -553.0,
    "sugars": 29.0,
    "protein": 107.6,
    "steps": 0
  }
}
"""#
}

// MARK: - Vista Widget

struct MacroBaraWidgetEntryView : View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry

    var body: some View {
        let d = entry.data
        switch family {
        case .systemSmall:
            smallWidgetView(d: d)
        default:
            mediumWidgetView(d: d)
        }
    }
    
    // MARK: - Layout Medium (Identico alla Hero Card dell'App)
    
    @ViewBuilder
    private func mediumWidgetView(d: WidgetDataModel) -> some View {
        let isTargetOk = d.todayKcal <= d.targetKcal + 50
        
        VStack(spacing: 7) {
            // 1. Header con Mascotte Capibara e Pill di Stato Positiva Verde
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(WidgetTheme.coralTerracotta)
                        .frame(width: 24, height: 24)
                    Text("🦫")
                        .font(.system(size: 13))
                }
                
                VStack(alignment: .leading, spacing: 0.5) {
                    Text(d.greeting)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Calorie assunte oggi")
                        .font(.system(size: 8.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
                
                Spacer()
                
                // Pill Verde Smeraldo Positiva se in target (non rossa!)
                HStack(spacing: 3) {
                    Text(isTargetOk ? "🎯" : "⚠️")
                        .font(.system(size: 9))
                    Text("\(d.percentTarget)% del target")
                        .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    isTargetOk
                        ? WidgetTheme.accentEmerald.opacity(0.22)
                        : WidgetTheme.accentRose.opacity(0.25)
                )
                .foregroundStyle(isTargetOk ? WidgetTheme.accentEmerald : WidgetTheme.accentRose)
                .clipShape(Capsule())
            }
            
            // 2. Kcal Assunte + Deficit Chiarito (Oggi vs Settimana)
            VStack(spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(d.todayKcal)")
                        .font(.system(size: 23, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/ \(d.targetKcal)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                    
                    Spacer()
                    
                    // Indicazione Chiara: Deficit Oggi e Settimana distinti
                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            Text("Oggi:")
                                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                            Text("\(d.todayDeficitKcal) kcal")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(WidgetTheme.accentEmerald)
                        }
                        
                        HStack(spacing: 2) {
                            Text("Sett:")
                                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                            Text("\(d.totalDeficitKcal) kcal")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .foregroundStyle(WidgetTheme.accentEmerald)
                        }
                    }
                }
                
                // Barra Progresso Terracotta
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: 3.5)
                        Capsule()
                            .fill(WidgetTheme.coralTerracotta)
                            .frame(
                                width: max(3.5, geo.size.width * CGFloat(min(1.0, Double(d.todayKcal) / Double(max(1, d.targetKcal))))),
                                height: 3.5
                            )
                    }
                }
                .frame(height: 3.5)
            }
            
            // 3. Le 3 Card Bianche Ottimizzate (Ricche di Informazioni senza Spazi Vuoti)
            HStack(spacing: 6) {
                // Card 1: Kcal Rimaste
                richWhiteCard(
                    icon: "flame.fill",
                    iconColor: WidgetTheme.coralTerracotta,
                    category: "Rimaste",
                    value: "\(d.kcalRemaining)",
                    unit: "kcal",
                    contextText: "Target 1.600",
                    progress: Double(d.todayKcal) / Double(max(1, d.targetKcal)),
                    progressColor: WidgetTheme.coralTerracotta
                )
                
                // Card 2: Proteine
                richWhiteCard(
                    icon: "dumbbell.fill",
                    iconColor: WidgetTheme.accentCyan,
                    category: "Proteine",
                    value: "\(Int(d.proteinG))",
                    unit: "g",
                    contextText: "su 130g (\(Int((d.proteinG / d.targetProteinG) * 100))%)",
                    progress: min(1.0, d.proteinG / d.targetProteinG),
                    progressColor: WidgetTheme.accentCyan
                )
                
                // Card 3: Zuccheri
                richWhiteCard(
                    icon: "heart.fill",
                    iconColor: WidgetTheme.accentRose,
                    category: "Zuccheri",
                    value: "\(Int(d.sugarsG))",
                    unit: "g",
                    contextText: "max 40g (Sotto)",
                    progress: min(1.0, d.sugarsG / d.maxSugarsG),
                    progressColor: d.sugarsG <= 40 ? WidgetTheme.accentEmerald : WidgetTheme.accentRose
                )
            }
            
            // 4. Barra dei 7 Giorni della Settimana (Colori Precisi per Grado)
            HStack(spacing: 4) {
                ForEach(d.dayGrades) { item in
                    let colors = WidgetTheme.colorsForGrade(item.grade)
                    VStack(spacing: 1.5) {
                        Text(item.day)
                            .font(.system(size: 7.5, weight: item.isToday ? .heavy : .bold, design: .rounded))
                            .foregroundStyle(item.isToday ? WidgetTheme.coralTerracotta : Color.white.opacity(0.6))
                        
                        Text(item.grade)
                            .font(.system(size: 7.5, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1.5)
                            .frame(minWidth: 18)
                            .background(colors.bg)
                            .foregroundStyle(colors.text)
                            .clipShape(RoundedRectangle(cornerRadius: 3.5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3.5)
                                    .strokeBorder(item.isToday ? WidgetTheme.coralTerracotta : Color.clear, lineWidth: 1.2)
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .containerBackground(for: .widget) {
            WidgetTheme.heroGradient
        }
    }
    
    // MARK: - Layout Small
    
    @ViewBuilder
    private func smallWidgetView(d: WidgetDataModel) -> some View {
        let isTargetOk = d.todayKcal <= d.targetKcal + 50
        
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                ZStack {
                    Circle()
                        .fill(WidgetTheme.coralTerracotta)
                        .frame(width: 20, height: 20)
                    Text("🦫")
                        .font(.system(size: 11))
                }
                Text("MacroBara")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(d.percentTarget)%")
                    .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(isTargetOk ? WidgetTheme.accentEmerald : WidgetTheme.accentRose)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(d.todayKcal)")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("/ \(d.targetKcal)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text("-\(abs(d.todayDeficitKcal))")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(WidgetTheme.accentEmerald)
                }
                
                Capsule()
                    .fill(WidgetTheme.coralTerracotta)
                    .frame(height: 3)
            }
            
            HStack(spacing: 5) {
                richWhiteCard(
                    icon: "dumbbell.fill",
                    iconColor: WidgetTheme.accentCyan,
                    category: "Pro",
                    value: "\(Int(d.proteinG))",
                    unit: "g",
                    contextText: "su 130g",
                    progress: min(1.0, d.proteinG / d.targetProteinG),
                    progressColor: WidgetTheme.accentCyan
                )
                
                richWhiteCard(
                    icon: "heart.fill",
                    iconColor: WidgetTheme.accentRose,
                    category: "Zuccheri",
                    value: "\(Int(d.sugarsG))",
                    unit: "g",
                    contextText: "max 40g",
                    progress: min(1.0, d.sugarsG / d.maxSugarsG),
                    progressColor: d.sugarsG <= 40 ? WidgetTheme.accentEmerald : WidgetTheme.accentRose
                )
            }
            
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 8.5))
                    .foregroundStyle(WidgetTheme.coralTerracotta)
                Text("\(d.kcalRemaining) kcal rimaste")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(11)
        .containerBackground(for: .widget) {
            WidgetTheme.heroGradient
        }
    }
    
    // MARK: - Mini Card Bianca Informativa & Spaziata Perfettamente
    
    private func richWhiteCard(
        icon: String,
        iconColor: Color,
        category: String,
        value: String,
        unit: String,
        contextText: String,
        progress: Double,
        progressColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 2.5) {
                Image(systemName: icon)
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(iconColor)
                Text(category.uppercased())
                    .font(.system(size: 7, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.secondary)
                Spacer()
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(WidgetTheme.heroEspressoDark)
                Text(" \(unit)")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.secondary)
            }
            
            // Micro Barra di Progresso Nutrizionale
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.18))
                        .frame(height: 2)
                    Capsule()
                        .fill(progressColor)
                        .frame(width: max(2, g.size.width * CGFloat(min(1.0, progress))), height: 2)
                }
            }
            .frame(height: 2)
            
            Text(contextText)
                .font(.system(size: 7, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Configurazione Principale Widget

@main
struct MacroBaraWidget: Widget {
    let kind: String = "MacroBaraWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            MacroBaraWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MacroBara Giornaliero")
        .description("Visualizza calorie assunte, deficit oggi/settimana, macro e streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
