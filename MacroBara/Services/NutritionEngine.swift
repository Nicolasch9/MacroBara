//
//  NutritionEngine.swift
//  MacroBara
//

import SwiftUI

struct GradeBreakdownItem {
    var title: String
    var score: Int
    var maxScore: Int
    var note: String
    var color: Color
}

struct DailyGrade {
    var grade: String
    var score: Int
    var title: String
    var summary: String
    var color: Color
    var breakdown: [GradeBreakdownItem]
    
    var isPending: Bool {
        grade == "⏳"
    }
}

final class NutritionEngine {
    static let shared = NutritionEngine()
    
    func calculateGrade(for log: DailyLog, profile: UserProfile) -> DailyGrade {
        let kcal = log.totalKcal
        let sugars = log.totalSugars
        let protein = log.totalProtein
        let steps = log.steps
        let tdee: Double = max(log.realTdee, profile.defaultTdeeKcal, 2150.0)
        let deficit = tdee - kcal
        
        if kcal == 0 && log.meals.isEmpty {
            return DailyGrade(
                grade: "⏳",
                score: 0,
                title: "⏳ Giornata in Corso",
                summary: "La giornata è iniziata. In attesa dei pasti serali.",
                color: Theme.accentCyan,
                breakdown: [
                    GradeBreakdownItem(title: "Zuccheri", score: 0, maxScore: 35, note: "In attesa", color: .secondary),
                    GradeBreakdownItem(title: "Deficit", score: 0, maxScore: 30, note: "In attesa", color: .secondary),
                    GradeBreakdownItem(title: "Proteine", score: 0, maxScore: 20, note: "In attesa", color: .secondary),
                    GradeBreakdownItem(title: "Attività", score: 0, maxScore: 15, note: "In attesa", color: .secondary)
                ]
            )
        }
        
        // 1. Sugars (Max 35) - Prevenzione Diabete
        let scoreSugars: Int
        let noteSugars: String
        let colorSugars: Color
        if sugars <= 25 {
            scoreSugars = 35
            noteSugars = "Zuccheri ottimi (\(Int(sugars))g / max 40g)"
            colorSugars = Theme.accentEmerald
        } else if sugars <= 40 {
            scoreSugars = 30
            noteSugars = "Sotto soglia di sicurezza (\(Int(sugars))g / 40g)"
            colorSugars = Theme.accentEmerald
        } else if sugars <= 55 {
            scoreSugars = 18
            noteSugars = "Leggermente oltre (\(Int(sugars))g vs 40g)"
            colorSugars = Theme.accentAmber
        } else if sugars <= 75 {
            scoreSugars = 10
            noteSugars = "Carico elevato (\(Int(sugars))g)"
            colorSugars = .orange
        } else {
            scoreSugars = 0
            noteSugars = "Allerta zuccheri critici (\(Int(sugars))g)"
            colorSugars = Theme.accentRose
        }
        
        // 2. Deficit (Max 30)
        let scoreDeficit: Int
        let noteDeficit: String
        let colorDeficit: Color
        if deficit >= 400 && deficit <= 750 {
            scoreDeficit = 30
            noteDeficit = "Deficit ideale (\(Int(deficit)) kcal)"
            colorDeficit = Theme.accentEmerald
        } else if deficit >= 200 && deficit < 400 {
            scoreDeficit = 26
            noteDeficit = "Buon deficit moderato (\(Int(deficit)) kcal)"
            colorDeficit = Theme.accentEmerald
        } else if deficit >= -100 && deficit < 200 {
            scoreDeficit = 22
            noteDeficit = "Bilancio neutro / mantenimento"
            colorDeficit = Theme.accentCyan
        } else if deficit > 750 {
            scoreDeficit = 25
            noteDeficit = "Deficit molto marcato (\(Int(deficit)) kcal)"
            colorDeficit = Theme.accentAmber
        } else if deficit >= -300 {
            scoreDeficit = 14
            noteDeficit = "Lieve surplus (+\(Int(abs(deficit))) kcal)"
            colorDeficit = Theme.accentAmber
        } else {
            scoreDeficit = 5
            noteDeficit = "Surplus energetico (+\(Int(abs(deficit))) kcal)"
            colorDeficit = Theme.accentRose
        }
        
        // 3. Protein (Max 20)
        let scoreProtein: Int
        let noteProtein: String
        let colorProtein: Color
        if protein >= 120 {
            scoreProtein = 20
            noteProtein = "Target proteico centrato (\(Int(protein))g / 130g)"
            colorProtein = Theme.accentEmerald
        } else if protein >= 100 {
            scoreProtein = 16
            noteProtein = "Buona quota proteica (\(Int(protein))g / 130g)"
            colorProtein = Theme.accentCyan
        } else if protein >= 80 {
            scoreProtein = 12
            noteProtein = "Quota proteica discreta (\(Int(protein))g)"
            colorProtein = Theme.accentAmber
        } else {
            scoreProtein = 6
            noteProtein = "Proteine da incrementare (\(Int(protein))g)"
            colorProtein = Theme.accentRose
        }
        
        // 4. Steps (Max 15)
        let scoreSteps: Int
        let noteSteps: String
        let colorSteps: Color
        if steps >= 12000 {
            scoreSteps = 15
            noteSteps = "Passi eccellenti (\(steps))"
            colorSteps = Theme.accentCyan
        } else if steps >= 8000 {
            scoreSteps = 13
            noteSteps = "Ottimo volume passi (\(steps))"
            colorSteps = Theme.accentEmerald
        } else if steps >= 5000 {
            scoreSteps = 10
            noteSteps = "Attività moderata (\(steps))"
            colorSteps = Theme.accentAmber
        } else if steps > 0 {
            scoreSteps = 5
            noteSteps = "Passi contenuti (\(steps))"
            colorSteps = .orange
        } else {
            scoreSteps = 0
            noteSteps = "Dati passi non registrati"
            colorSteps = .secondary
        }
        
        let totalScore = min(100, scoreSugars + scoreDeficit + scoreProtein + scoreSteps)
        
        let gradeLetter: String
        let title: String
        let summary: String
        let badgeColor: Color
        
        switch totalScore {
        case 95...100:
            gradeLetter = "A+++"
            title = "👑 Livello Mitico"
            summary = "Giornata eccezionale! Zuccheri minimi, deficit ideale e proteine al top."
            badgeColor = Theme.accentAmber
        case 88...94:
            gradeLetter = "A++"
            title = "💎 Livello Eccellente"
            summary = "Aderenza di altissimo livello sia metabolica che nutrizionale."
            badgeColor = Theme.accentEmerald
        case 80...87:
            gradeLetter = "A+"
            title = "🥇 Ottima Giornata"
            summary = "Target pienamente rispettati, ottima protezione metabolica."
            badgeColor = Theme.accentEmerald
        case 72...79:
            gradeLetter = "A"
            title = "⭐ Buona Giornata"
            summary = "Buon equilibrio generale con piccoli margini di ottimizzazione."
            badgeColor = Theme.accentCyan
        case 62...71:
            gradeLetter = "B+"
            title = "⚖️ Sufficiente"
            summary = "Valori discreti, attenzione agli zuccheri o alla quota proteica."
            badgeColor = Theme.accentAmber
        case 50...61:
            gradeLetter = "B"
            title = "⚠️ Da Ottimizzare"
            summary = "Qualche sbilanciamento calorico o zuccheri oltre soglia."
            badgeColor = .orange
        default:
            gradeLetter = "C"
            title = "🔄 Reset Richiesto"
            summary = "Giornata fuori target. Domani si riparte con calma e disciplina zen."
            badgeColor = Theme.accentRose
        }
        
        return DailyGrade(
            grade: gradeLetter,
            score: totalScore,
            title: title,
            summary: summary,
            color: badgeColor,
            breakdown: [
                GradeBreakdownItem(title: "Zuccheri (<40g)", score: scoreSugars, maxScore: 35, note: noteSugars, color: colorSugars),
                GradeBreakdownItem(title: "Deficit Energetico", score: scoreDeficit, maxScore: 30, note: noteDeficit, color: colorDeficit),
                GradeBreakdownItem(title: "Proteine (130g)", score: scoreProtein, maxScore: 20, note: noteProtein, color: colorProtein),
                GradeBreakdownItem(title: "Attività Watch", score: scoreSteps, maxScore: 15, note: noteSteps, color: colorSteps)
            ]
        )
    }
}
