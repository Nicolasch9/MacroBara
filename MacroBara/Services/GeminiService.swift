//
//  GeminiService.swift
//  MacroBara
//

import Foundation

enum GeminiModelOption: String, CaseIterable, Identifiable {
    case gemini38Flash = "gemini-3.8-flash"
    case gemini38Pro = "gemini-3.8-pro"
    case gemini25Flash = "gemini-2.5-flash"
    case gemini20Flash = "gemini-2.0-flash"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .gemini38Flash: return "Gemini 3.8 Flash (Consigliato • Più recente)"
        case .gemini38Pro: return "Gemini 3.8 Pro (Massima Accuratezza • Pro)"
        case .gemini25Flash: return "Gemini 2.5 Flash"
        case .gemini20Flash: return "Gemini 2.0 Flash"
        }
    }
    
    var badgeName: String {
        switch self {
        case .gemini38Flash: return "Gemini 3.8 Flash"
        case .gemini38Pro: return "Gemini 3.8 Pro"
        case .gemini25Flash: return "Gemini 2.5 Flash"
        case .gemini20Flash: return "Gemini 2.0 Flash"
        }
    }
}

struct GeminiMealAnalysis: Codable {
    var title: String
    var mealType: String
    var foodDescription: String
    var kcal: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var sugarsG: Double
    var notes: String
    var isFromCloud: Bool = false
    var modelUsed: String = "Locale"
}

@Observable
final class GeminiService {
    static let shared = GeminiService()
    
    // API Key memorizzata in UserDefaults
    var apiKey: String {
        get {
            UserDefaults.standard.string(forKey: "gemini_api_key") ?? ""
        }
        set {
            UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "gemini_api_key")
        }
    }
    
    // Modello selezionato
    var selectedModel: GeminiModelOption {
        get {
            let saved = UserDefaults.standard.string(forKey: "gemini_selected_model") ?? GeminiModelOption.gemini38Flash.rawValue
            return GeminiModelOption(rawValue: saved) ?? .gemini38Flash
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "gemini_selected_model")
        }
    }
    
    var hasValidKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var isAnalyzing: Bool = false
    var lastError: String? = nil
    var lastSourceUsed: String = "Locale"
    
    func analyzeMeal(prompt: String) async throws -> GeminiMealAnalysis {
        await MainActor.run {
            self.isAnalyzing = true
            self.lastError = nil
        }
        
        defer {
            Task { @MainActor in
                self.isAnalyzing = false
            }
        }
        
        let cleanedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Se non c'è una chiave API configurata, usa il motore nutrizionale avanzato locale
        if cleanedKey.isEmpty {
            await MainActor.run { self.lastSourceUsed = "Database Locale" }
            return advancedLocalAnalysis(prompt: prompt)
        }
        
        // Tenta prima con il modello selezionato (default: gemini-3.8-flash)
        let primaryModel = selectedModel.rawValue
        let fallbackModels = [
            primaryModel,
            GeminiModelOption.gemini38Flash.rawValue,
            GeminiModelOption.gemini25Flash.rawValue,
            GeminiModelOption.gemini20Flash.rawValue
        ]
        
        var attemptedModels: [String] = []
        
        for modelToTry in fallbackModels {
            if attemptedModels.contains(modelToTry) { continue }
            attemptedModels.append(modelToTry)
            
            do {
                let analysis = try await executeApiCall(model: modelToTry, key: cleanedKey, prompt: prompt)
                await MainActor.run {
                    self.lastSourceUsed = "\(modelToTry) (Cloud)"
                }
                return analysis
            } catch let apiError as ApiCallError {
                if apiError.statusCode == 404 || apiError.statusCode == 400 {
                    // Se il modello non è disponibile per questa chiave, prova il prossimo
                    print("Modello \(modelToTry) non supportato (status \(apiError.statusCode)), provo fallback...")
                    continue
                } else {
                    // Errore di autenticazione o quota: interrompi e fallback a locale
                    await MainActor.run {
                        self.lastError = "Errore API (\(apiError.statusCode)): \(apiError.message)"
                        self.lastSourceUsed = "Database Locale (Fallback errore API)"
                    }
                    return advancedLocalAnalysis(prompt: prompt, fallbackNotice: "⚠️ Errore API Cloud (\(apiError.statusCode)). Valori calcolati tramite database nutrizionale locale.")
                }
            } catch {
                print("Gemini Network Error: \(error.localizedDescription)")
                await MainActor.run {
                    self.lastError = error.localizedDescription
                    self.lastSourceUsed = "Database Locale (Errore connessione)"
                }
                return advancedLocalAnalysis(prompt: prompt, fallbackNotice: "⚠️ Offline. Valori calcolati tramite database nutrizionale scientifico locale.")
            }
        }
        
        return advancedLocalAnalysis(prompt: prompt, fallbackNotice: "⚠️ Nessun modello cloud disponibile. Calcolo locale completato.")
    }
    
    private struct ApiCallError: Error {
        let statusCode: Int
        let message: String
    }
    
    private func executeApiCall(model: String, key: String, prompt: String) async throws -> GeminiMealAnalysis {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)") else {
            throw ApiCallError(statusCode: 400, message: "URL non valido")
        }
        
        let systemInstruction = """
        Sei il nutrizionista e biologo computazionale di MacroBara (motore basato su \(model)).
        L'utente descrive cosa ha mangiato in linguaggio naturale (es. '100g di macinato con 100g di anelletti', oppure 'porridge con avena, chia e whey').
        Il tuo compito è stimare con la massima accuratezza nutrizionale e scientifica calorie e macronutrienti.
        
        REGOLE FONDAMENTALI DI CHIMICA DEGLI ALIMENTI:
        1. Carne macinata di manzo (100g cruda): ~215 kcal, 20-22g proteine nobili, 0g carboidrati, 13-15g grassi, 0g zuccheri.
        2. Pasta secca (es. anelletti, penne, spaghetti) (100g cruda): ~355 kcal, 12-13g proteine vegetali, 72-74g carboidrati complessi, 1.5g grassi, 1-2g zuccheri.
        3. Se l'utente specifica grammature multiple (es. 100g macinato + 100g pasta), DEVI SOMMARE TUTTI GLI ALIMENTI in modo coerente (in questo esempio: ~570 kcal, ~34g proteine, ~73g carboidrati, ~16g grassi).
        4. Stima con estrema cura gli Zuccheri Semplici (sugarsG) per monitorare la soglia preventiva metabolica (< 40g/die).
        
        Rispondi ESCLUSIVAMENTE con un JSON valido con questa struttura esatta, senza formattazione markdown e senza backtick:
        {
          "title": "Colazione / Pranzo / Cena / Snack / Bevande",
          "mealType": "Colazione / Pranzo / Cena / Snack / Bevande",
          "foodDescription": "Descrizione sintetica con grammature e alimenti rilevati",
          "kcal": 570.0,
          "proteinG": 34.0,
          "carbsG": 73.0,
          "fatG": 16.0,
          "sugarsG": 2.0,
          "notes": "Spiegazione sintetica dell'impatto metabolico e profilo nutrizionale"
        }
        """
        
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [
                        ["text": "\(systemInstruction)\n\nPasto consumato dall'utente: \"\(prompt)\""]
                    ]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.1
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiCallError(statusCode: 500, message: "Risposta HTTP invalida")
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "Errore sconosciuto"
            throw ApiCallError(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = root["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw ApiCallError(statusCode: 500, message: "Struttura risposta non conforme")
        }
        
        let cleanedText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
        
        guard let jsonData = cleanedText.data(using: .utf8) else {
            throw ApiCallError(statusCode: 500, message: "Encoding JSON fallito")
        }
        
        var decoded = try JSONDecoder().decode(GeminiMealAnalysis.self, from: jsonData)
        decoded.isFromCloud = true
        decoded.modelUsed = model
        return decoded
    }
    
    // MARK: - Motore Nutrizionale Locale Intelligente (Offline Fallback)
    
    /// Analizza scientificamente il testo anche in assenza di connessione o senza API key,
    /// individuando sia gli alimenti che le relative grammature (es. '100 grammi di macinato e 100 grammi di pasta').
    private func advancedLocalAnalysis(prompt: String, fallbackNotice: String? = nil) -> GeminiMealAnalysis {
        let p = prompt.lowercased()
        
        // Dizionario nutrizionale per 100g di alimento (Tabelle CREA / USDA)
        // (Kcal, Proteine, Carbi, Grassi, Zuccheri)
        struct FoodProfile {
            let name: String
            let keywords: [String]
            let kcal100: Double
            let pro100: Double
            let carb100: Double
            let fat100: Double
            let sugar100: Double
            let defaultGrams: Double
        }
        
        let referenceDatabase: [FoodProfile] = [
            // Carni
            FoodProfile(name: "Macinato di Manzo", keywords: ["macinato", "tritata", "carne trita", "carne macinata", "hamburger"], kcal100: 215, pro100: 21.0, carb100: 0.0, fat100: 14.5, sugar100: 0.0, defaultGrams: 100),
            FoodProfile(name: "Petto di Pollo", keywords: ["pollo", "tacchino", "fesa di tacchino"], kcal100: 165, pro100: 34.5, carb100: 0.0, fat100: 2.0, sugar100: 0.0, defaultGrams: 150),
            FoodProfile(name: "Bistecca di Manzo", keywords: ["manzo", "bistecca", "vitello", "scottona"], kcal100: 190, pro100: 31.5, carb100: 0.0, fat100: 6.5, sugar100: 0.0, defaultGrams: 150),
            
            // Pasta e Cereali
            FoodProfile(name: "Pasta di Semola", keywords: ["pasta", "anelletti", "spaghetti", "penne", "rigatoni", "fusilli", "tagliatelle"], kcal100: 355, pro100: 12.5, carb100: 73.0, fat100: 1.5, sugar100: 1.0, defaultGrams: 80),
            FoodProfile(name: "Riso Basmati/Arborio", keywords: ["riso", "basmati", "risotto"], kcal100: 360, pro100: 7.0, carb100: 78.0, fat100: 0.8, sugar100: 0.0, defaultGrams: 80),
            FoodProfile(name: "Avena / Porridge", keywords: ["avena", "porridge", "fiocchi d'avena", "fiocchi avena"], kcal100: 370, pro100: 13.5, carb100: 60.0, fat100: 7.0, sugar100: 1.0, defaultGrams: 40),
            FoodProfile(name: "Pane Comune", keywords: ["pane", "panino", "ciabatta"], kcal100: 260, pro100: 8.5, carb100: 50.0, fat100: 1.5, sugar100: 2.0, defaultGrams: 60),
            
            // Pesce
            FoodProfile(name: "Salmone Fresco", keywords: ["salmone", "salmone ai ferri"], kcal100: 280, pro100: 30.0, carb100: 0.0, fat100: 17.0, sugar100: 0.0, defaultGrams: 150),
            FoodProfile(name: "Tonno Naturale", keywords: ["tonno", "tonno al naturale"], kcal100: 100, pro100: 24.0, carb100: 0.0, fat100: 0.8, sugar100: 0.0, defaultGrams: 100),
            FoodProfile(name: "Merluzzo / Orata", keywords: ["merluzzo", "orata", "spigola", "pesce bianco"], kcal100: 90, pro100: 19.0, carb100: 0.0, fat100: 1.0, sugar100: 0.0, defaultGrams: 150),
            
            // Uova & Latticini
            FoodProfile(name: "Uova Intere", keywords: ["uova", "uovo"], kcal100: 140, pro100: 12.5, carb100: 0.6, fat100: 9.8, sugar100: 0.0, defaultGrams: 100),
            FoodProfile(name: "Albume", keywords: ["albume", "albumi"], kcal100: 50, pro100: 11.0, carb100: 0.7, fat100: 0.2, sugar100: 0.0, defaultGrams: 100),
            FoodProfile(name: "Yogurt Greco 0%", keywords: ["yogurt greco", "yogurt magro"], kcal100: 60, pro100: 10.3, carb100: 3.8, fat100: 0.0, sugar100: 3.8, defaultGrams: 150),
            FoodProfile(name: "Whey Protein", keywords: ["whey", "proteine in polvere", "proteine isolate"], kcal100: 380, pro100: 80.0, carb100: 5.0, fat100: 3.0, sugar100: 2.0, defaultGrams: 25),
            FoodProfile(name: "Parmigiano Reggiano", keywords: ["parmigiano", "grana"], kcal100: 390, pro100: 33.0, carb100: 0.0, fat100: 28.0, sugar100: 0.0, defaultGrams: 15),
            FoodProfile(name: "Mozzarella", keywords: ["mozzarella"], kcal100: 250, pro100: 18.0, carb100: 1.0, fat100: 19.0, sugar100: 1.0, defaultGrams: 100),
            
            // Condimenti & Grassi
            FoodProfile(name: "Olio EVO", keywords: ["olio", "olio evo", "olio d'oliva"], kcal100: 884, pro100: 0.0, carb100: 0.0, fat100: 100.0, sugar100: 0.0, defaultGrams: 10),
            FoodProfile(name: "Frutta Secca", keywords: ["noci", "mandorle", "anacardi", "arachidi"], kcal100: 600, pro100: 18.0, carb100: 15.0, fat100: 50.0, sugar100: 4.0, defaultGrams: 20),
            
            // Frutta
            FoodProfile(name: "Banana", keywords: ["banana", "banane"], kcal100: 89, pro100: 1.1, carb100: 22.8, fat100: 0.3, sugar100: 12.2, defaultGrams: 100),
            FoodProfile(name: "Mela / Pera", keywords: ["mela", "mele", "pera", "pere"], kcal100: 52, pro100: 0.3, carb100: 13.8, fat100: 0.2, sugar100: 10.0, defaultGrams: 150),
            FoodProfile(name: "Miele / Zucchero", keywords: ["miele", "zucchero"], kcal100: 304, pro100: 0.3, carb100: 82.4, fat100: 0.0, sugar100: 82.0, defaultGrams: 15),
            
            // Dolci / Preparazioni
            FoodProfile(name: "Pancake", keywords: ["pancake", "pancakes"], kcal100: 227, pro100: 6.4, carb100: 28.3, fat100: 9.7, sugar100: 4.4, defaultGrams: 150),
            FoodProfile(name: "Biscotti", keywords: ["biscotti", "frollini"], kcal100: 450, pro100: 7.0, carb100: 70.0, fat100: 15.0, sugar100: 25.0, defaultGrams: 40)
        ]
        
        var totalKcal: Double = 0
        var totalPro: Double = 0
        var totalCarb: Double = 0
        var totalFat: Double = 0
        var totalSugars: Double = 0
        var detectedFoodsList: [String] = []
        
        // Funzione per cercare una grammatura associata ad una parola chiave
        // Es: "100 grammi di macinato", "100g pasta", "macinato 150g"
        func extractGrams(for keyword: String, in text: String, fallback: Double) -> Double {
            // Pattern 1: [numero] (g|gr|grammi) [parola]
            let patternBefore = "(\\d+)\\s*(?:g|gr|grammi)?\\s*(?:di)?\\s*\(keyword)"
            if let regex = try? NSRegularExpression(pattern: patternBefore, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
                if let numRange = Range(match.range(at: 1), in: text), let val = Double(text[numRange]) {
                    return val
                }
            }
            // Pattern 2: [parola] [numero] (g|gr|grammi)
            let patternAfter = "\(keyword)\\s*(\\d+)\\s*(?:g|gr|grammi)?"
            if let regex = try? NSRegularExpression(pattern: patternAfter, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) {
                if let numRange = Range(match.range(at: 1), in: text), let val = Double(text[numRange]) {
                    return val
                }
            }
            return fallback
        }
        
        // Analisi di ciascun profilo nel database
        for profile in referenceDatabase {
            for keyword in profile.keywords {
                if p.contains(keyword) {
                    let grams = extractGrams(for: keyword, in: p, fallback: profile.defaultGrams)
                    let factor = grams / 100.0
                    
                    let k = (profile.kcal100 * factor).rounded()
                    let pro = ((profile.pro100 * factor) * 10).rounded() / 10
                    let carb = ((profile.carb100 * factor) * 10).rounded() / 10
                    let fat = ((profile.fat100 * factor) * 10).rounded() / 10
                    let sug = ((profile.sugar100 * factor) * 10).rounded() / 10
                    
                    totalKcal += k
                    totalPro += pro
                    totalCarb += carb
                    totalFat += fat
                    totalSugars += sug
                    
                    detectedFoodsList.append("\(Int(grams))g \(profile.name)")
                    break // Non contare due volte lo stesso profilo se ha più keyword
                }
            }
        }
        
        // Se nessun alimento specifico è stato riconosciuto, stima generica prudenziale
        if detectedFoodsList.isEmpty {
            totalKcal = 350
            totalPro = 18
            totalCarb = 40
            totalFat = 12
            totalSugars = 5
            detectedFoodsList.append(prompt)
        }
        
        // Rileva MealType dal contesto
        var mealType = "Spuntino"
        if p.contains("colazione") || p.contains("pancake") || p.contains("porridge") || p.contains("caffè") {
            mealType = "Colazione"
        } else if p.contains("pranzo") || p.contains("pasta") || p.contains("anelletti") || p.contains("riso") {
            mealType = "Pranzo"
        } else if p.contains("cena") || p.contains("pollo") || p.contains("salmone") {
            mealType = "Cena"
        }
        
        let desc = detectedFoodsList.joined(separator: " + ")
        let defaultNote = fallbackNotice ?? "📦 Valori calcolati tramite Database Scientifico Locale (CREA/USDA). Configura l'API Key in alto per abilitare Gemini 2.0 Flash in cloud."
        
        return GeminiMealAnalysis(
            title: mealType,
            mealType: mealType,
            foodDescription: desc,
            kcal: (totalKcal * 10).rounded() / 10,
            proteinG: (totalPro * 10).rounded() / 10,
            carbsG: (totalCarb * 10).rounded() / 10,
            fatG: (totalFat * 10).rounded() / 10,
            sugarsG: (totalSugars * 10).rounded() / 10,
            notes: defaultNote,
            isFromCloud: false
        )
    }
}
