//
//  AddMealView.swift
//  MacroBara
//

import SwiftUI
import SwiftData

struct MealPreset: Identifiable {
    var id: String { title }
    var title: String
    var subtitle: String
    var icon: String
    var mealType: MealType
    var kcal: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var sugars: Double
    var ingredients: [String]
    var physiologicalImpact: String
}

struct AddMealView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    var log: DailyLog
    
    // Campi Form Pasto
    @State private var selectedType: MealType = .colazione
    @State private var descriptionText: String = ""
    @State private var kcalValue: Double = 0
    @State private var proteinValue: Double = 0
    @State private var carbsValue: Double = 0
    @State private var fatValue: Double = 0
    @State private var sugarsValue: Double = 0
    @State private var notesText: String = ""
    
    // Gemini AI State
    @State private var aiPromptText: String = ""
    @State private var gemini = GeminiService.shared
    @State private var aiThinkingPhase: Int = 0
    @State private var isGeminiThinking: Bool = false
    @State private var gradientRotation: Double = 0
    
    // Presets
    @State private var selectedPresetForPreview: MealPreset? = nil
    
    // API Key Sheet
    @State private var showingApiKeySheet: Bool = false
    
    // Post-Save Alert
    @State private var showingPostSaveAlert = false
    @State private var lastSavedMealTitle: String = ""
    
    // Database Ricerca
    @State private var searchText: String = ""
    @State private var selectedFood: FoodItem? = nil
    @State private var foodGrams: Double = 100
    
    private let geminiColors: [Color] = [
        Color(red: 0.1, green: 0.45, blue: 0.95),  // Electric Blue
        Color(red: 0.6, green: 0.25, blue: 0.95),  // Purple
        Color(red: 0.95, green: 0.3, blue: 0.65),  // Pink
        Color(red: 0.0, green: 0.85, blue: 0.95)   // Cyan
    ]
    
    private let thinkingMessages = [
        "🧠 Analisi alimenti e grammature stimate...",
        "🔬 Calcolo indice glicemico e zuccheri semplici...",
        "⚖️ Bilanciamento calorie e profilo aminoacidico...",
        "✨ Finalizzazione stima metabolica..."
    ]
    
    private let presets: [MealPreset] = [
        MealPreset(
            title: "Porridge Standard Marco",
            subtitle: "410 kcal • Colazione Abituale",
            icon: "cup.and.saucer.fill",
            mealType: .colazione,
            kcal: 410,
            protein: 25,
            carbs: 36,
            fat: 17,
            sugars: 6,
            ingredients: [
                "40g Fiocchi d'avena integrali",
                "20g Whey Protein Isolate",
                "10g Semi di chia",
                "150ml Latte di mandorla senza zuccheri",
                "5g Anacardi al naturale",
                "15g Cioccolato fondente 70%"
            ],
            physiologicalImpact: "Rilascio energetico graduale (4-5 ore di sazietà piena). I beta-glucani dell'avena e le mucillagini della chia eliminano i picchi insulinici mattutini."
        ),
        MealPreset(
            title: "Porridge Yogurt Magro (P2)",
            subtitle: "296 kcal • Ipocalorico / High Protein",
            icon: "leaf.fill",
            mealType: .colazione,
            kcal: 296,
            protein: 21,
            carbs: 21.3,
            fat: 13.3,
            sugars: 5,
            ingredients: [
                "20g Fiocchi d'avena",
                "10g Whey al cioccolato",
                "5g Semi di chia",
                "15g Cioccolato fondente 70%",
                "5g Anacardi al naturale",
                "150g Yogurt greco 0% grassi"
            ],
            physiologicalImpact: "Quota calorica ridotta con caseina a lento rilascio e fermenti lattici probiotici. Ideale per giornate a deficit calorico più marcato."
        ),
        MealPreset(
            title: "3 Pancake Fit con Frutta",
            subtitle: "535 kcal • Ricarica & Gusto",
            icon: "flame.fill",
            mealType: .colazione,
            kcal: 535,
            protein: 24.2,
            carbs: 73.4,
            fat: 16.6,
            sugars: 14,
            ingredients: [
                "3 Pancake fit d'avena",
                "150g Yogurt greco 0%",
                "1 Banana media (100g)",
                "80g Mirtilli freschi",
                "1 Cucchiaino di miele millefiori",
                "Cannella in polvere"
            ],
            physiologicalImpact: "Eccellente ricarica di glicogeno muscolare e potassio con antociani antiossidanti dai mirtilli. Zuccheri ben tollerati e sotto soglia."
        ),
        MealPreset(
            title: "Pollo & Riso Basmati",
            subtitle: "470 kcal • Pranzo / Cena Pulito",
            icon: "fork.knife",
            mealType: .pranzo,
            kcal: 470,
            protein: 38,
            carbs: 62,
            fat: 11,
            sugars: 1,
            ingredients: [
                "150g Petto di pollo ai ferri",
                "80g Riso basmati pesato a crudo",
                "10g Olio extravergine d'oliva a crudo",
                "Contorno di zucchine grigliate"
            ],
            physiologicalImpact: "Massimo effetto termico del cibo (TEF). Zuccheri praticamente a zero, alta densità proteica per preservare la massa magra."
        ),
        MealPreset(
            title: "Poke Bowl Salmone & Gamberi",
            subtitle: "555 kcal • Omega-3 & Anti-infiammatorio",
            icon: "fish.fill",
            mealType: .pranzo,
            kcal: 555,
            protein: 35.1,
            carbs: 51.2,
            fat: 24.6,
            sugars: 7,
            ingredients: [
                "Riso basmati cotto",
                "100g Salmone fresco a cubetti",
                "50g Gamberi al vapore",
                "Edamame & Carote",
                "50g Avocado fresco",
                "Feta magra sbriciolata",
                "Salsa teriyaki leggera & Sesamo"
            ],
            physiologicalImpact: "Acidi grassi Omega-3 EPA/DHA e grassi monoinsaturi che migliorano la sensibilità insulinica e riducono l'infiammazione sistemica."
        )
    ]
    
    private var filteredFoods: [FoodItem] {
        if searchText.isEmpty { return FoodItem.database }
        return FoodItem.database.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // 1. SEZIONE GEMINI AI
                    geminiAiCard
                    
                    // 2. SEZIONE PRESET RAPIDI (Schede ampie e interattive)
                    presetsHorizontalSection
                    
                    // 3. TIPO DI PASTO
                    mealTypePickerCard
                    
                    // 4. DATI NUTRIZIONALI (Con Icone e Stepper +- per ogni macro)
                    nutritionalDataCard
                    
                    // 5. DATABASE ALIMENTI RAPIDO
                    foodDatabaseCard
                    
                    // 6. NOTE & SENSAZIONI (In fondo, ampio spazio espandibile)
                    notesAndSensationsCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Registra Pasto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveCurrentMeal()
                    }
                    .bold()
                    .disabled(descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && kcalValue == 0)
                }
            }
            .sheet(item: $selectedPresetForPreview) { preset in
                presetPreviewSheet(preset)
            }
            .sheet(isPresented: $showingApiKeySheet) {
                NavigationStack {
                    Form {
                        Section {
                            SecureField("Incolla qui la chiave API (AIza...)", text: Bindable(gemini).apiKey)
                                .font(.system(.body, design: .monospaced))
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            
                            if !gemini.apiKey.isEmpty {
                                Button(role: .destructive) {
                                    gemini.apiKey = ""
                                } label: {
                                    Label("Rimuovi Chiave", systemImage: "trash")
                                }
                            }
                        } header: {
                            Text("Google AI Studio API Key")
                        } footer: {
                            Text("La chiave viene salvata esclusivamente nel portachiavi locale del tuo iPhone.")
                        }
                        
                        Section("Modello Gemini (Google AI)") {
                            Picker("Versione Modello", selection: Bindable(gemini).selectedModel) {
                                ForEach(GeminiModelOption.allCases) { model in
                                    Text(model.displayName).tag(model)
                                }
                            }
                            .pickerStyle(.inline)
                        }
                        
                        Section("Come ottenere la chiave gratuita") {
                            Text("1. Apri Google AI Studio (aistudio.google.com).")
                            Text("2. Clicca su 'Get API key' e genera una chiave gratuita con il tuo account Google.")
                            Text("3. Incollala qui sopra per abilitare Gemini 3.8 Flash o 3.8 Pro in cloud con precisione neurale.")
                            
                            Link("Apri Google AI Studio ↗", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                                .font(.system(.subheadline, design: .rounded).bold())
                        }
                    }
                    .navigationTitle("Configura Gemini AI")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Salva") {
                                showingApiKeySheet = false
                            }
                            .bold()
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .alert("Pasto Registrato! 🍽️", isPresented: $showingPostSaveAlert) {
                Button("Aggiungi un altro pasto") {
                    resetFormForNextMeal()
                }
                Button("Ho terminato", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Hai salvato '\(lastSavedMealTitle)'. Vuoi registrare subito un altro pasto per oggi o hai finito?")
            }
        }
    }
    
    // MARK: - 1. Gemini AI Card con Animazione Avanzata
    
    private var geminiAiCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: geminiColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                
                Text("AI NUTRIZIONISTA")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    showingApiKeySheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: gemini.hasValidKey ? "checkmark.circle.fill" : "key.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(gemini.hasValidKey ? gemini.selectedModel.badgeName : "Configura API Key")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(gemini.hasValidKey ? Color.green.opacity(0.12) : Color.orange.opacity(0.15))
                    .foregroundStyle(gemini.hasValidKey ? Color.green : Color.orange)
                    .clipShape(Capsule())
                }
            }
            
            // Box di Testo con Bordo Animato
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
                
                if isGeminiThinking {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            AngularGradient(
                                colors: geminiColors + geminiColors,
                                center: .center,
                                angle: .degrees(gradientRotation)
                            ),
                            lineWidth: 2.5
                        )
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Descrivi cosa hai mangiato (es. 100g macinato di manzo e 100g pasta tipo anelletti...)", text: $aiPromptText, axis: .vertical)
                        .lineLimit(2...6)
                        .font(.system(.body, design: .rounded))
                        .padding(10)
                        .disabled(isGeminiThinking)
                    
                    if isGeminiThinking {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(geminiColors[0])
                                .scaleEffect(0.85)
                            
                            Text(thinkingMessages[aiThinkingPhase % thinkingMessages.count])
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(geminiColors[1])
                                .transition(.opacity)
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                    }
                }
            }
            
            // Stato sorgente e suggerimento API Key
            HStack(spacing: 6) {
                if gemini.hasValidKey {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                    Text("Motore Cloud \(gemini.selectedModel.badgeName) attivo.")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "server.rack")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                    Text("Database Locale Scientifico attivo. Tocca 'Configura API Key' per \(gemini.selectedModel.badgeName).")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 2)
            
            // Pulsante Genera con Effetto Gemini
            Button {
                Task {
                    await startGeminiReasoningFlow()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isGeminiThinking ? "brain.head.profile" : "wand.and.stars")
                        .font(.system(size: 14, weight: .bold))
                    Text(isGeminiThinking ? "Gemini sta ragionando..." : "Calcola Calorie & Macro con Gemini")
                        .font(.system(.subheadline, design: .rounded).bold())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: isGeminiThinking ? [geminiColors[1], geminiColors[2]] : [geminiColors[0], geminiColors[1]],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: geminiColors[0].opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .disabled(aiPromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGeminiThinking)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }
    
    // MARK: - 2. Sezione Preset con Carte Spaziose
    
    private var presetsHorizontalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PRESET RAPIDI SALVATI")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Tocca per dettagli o salvataggio")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(presets) { preset in
                        Button {
                            selectedPresetForPreview = preset
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    ZStack {
                                        Circle()
                                            .fill(Theme.accentEmerald.opacity(0.15))
                                            .frame(width: 32, height: 32)
                                        Image(systemName: preset.icon)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Theme.accentEmerald)
                                    }
                                    Spacer()
                                    Text("\(Int(preset.kcal)) kcal")
                                        .font(.system(.caption, design: .rounded).bold())
                                        .foregroundStyle(Theme.accentCyan)
                                }
                                
                                Text(preset.title)
                                    .font(.system(.subheadline, design: .rounded).bold())
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                
                                Text(preset.subtitle)
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(.secondary)
                                
                                HStack(spacing: 6) {
                                    Text("P: \(Int(preset.protein))g")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Theme.accentEmerald.opacity(0.12))
                                        .foregroundStyle(Theme.accentEmerald)
                                        .clipShape(Capsule())
                                    
                                    Text("Z: \(Int(preset.sugars))g")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(preset.sugars <= 10 ? Theme.accentCyan.opacity(0.12) : Theme.accentAmber.opacity(0.12))
                                        .foregroundStyle(preset.sugars <= 10 ? Theme.accentCyan : Theme.accentAmber)
                                        .clipShape(Capsule())
                                }
                            }
                            .frame(width: 175)
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 3. Tipo di Pasto
    
    private var mealTypePickerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TIPO DI PASTO")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            
            Picker("Pasto", selection: $selectedType) {
                ForEach(MealType.selectableCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - 4. Dati Nutrizionali con Stepper +-
    
    private var nutritionalDataCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DETTAGLIO NUTRIZIONALE & ALIMENTI")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            
            // Descrizione Alimenti Espandibile
            VStack(alignment: .leading, spacing: 4) {
                Text("Alimenti consumati")
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundStyle(.secondary)
                
                TextField("Descrizione alimenti...", text: $descriptionText, axis: .vertical)
                    .lineLimit(2...6)
                    .padding(10)
                    .background(Color(.systemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            Divider()
            
            // Riga Calorie con Stepper +-25 / +-50
            macroStepperRow(
                icon: "flame.fill",
                iconColor: .orange,
                title: "Calorie",
                unit: "kcal",
                value: $kcalValue,
                step: 25,
                quickSteps: [-50, -25, 25, 50]
            )
            
            Divider()
            
            // Riga Proteine
            macroStepperRow(
                icon: "figure.strengthtraining.traditional",
                iconColor: Theme.accentEmerald,
                title: "Proteine",
                unit: "g",
                value: $proteinValue,
                step: 1,
                quickSteps: [-5, -1, 1, 5]
            )
            
            Divider()
            
            // Riga Carboidrati
            macroStepperRow(
                icon: "leaf.circle.fill",
                iconColor: Theme.accentAmber,
                title: "Carboidrati",
                unit: "g",
                value: $carbsValue,
                step: 1,
                quickSteps: [-5, -1, 1, 5]
            )
            
            Divider()
            
            // Riga Grassi
            macroStepperRow(
                icon: "drop.fill",
                iconColor: Theme.accentRose,
                title: "Grassi",
                unit: "g",
                value: $fatValue,
                step: 1,
                quickSteps: [-5, -1, 1, 5]
            )
            
            Divider()
            
            // Riga Zuccheri Semplici
            macroStepperRow(
                icon: "shield.lefthalf.filled",
                iconColor: sugarsValue <= 10 ? Theme.accentCyan : Theme.accentRose,
                title: "Zuccheri semplici (<40g)",
                unit: "g",
                value: $sugarsValue,
                step: 1,
                quickSteps: [-5, -1, 1, 5]
            )
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Componente Stepper per Macro
    
    private func macroStepperRow(
        icon: String,
        iconColor: Color,
        title: String,
        unit: String,
        value: Binding<Double>,
        step: Double,
        quickSteps: [Double]
    ) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 30, height: 30)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(iconColor)
                }
                
                Text(title)
                    .font(.system(.subheadline, design: .rounded).bold())
                
                Spacer()
                
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    TextField("0", value: value, format: .number)
                        .font(.system(.headline, design: .rounded).bold())
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                    Text(unit)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 4) {
                    Button {
                        value.wrappedValue = max(0, value.wrappedValue - step)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                    
                    Button {
                        value.wrappedValue += step
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(iconColor)
                    }
                }
            }
            
            // Pulsantini rapidi +-
            HStack(spacing: 8) {
                Spacer()
                ForEach(quickSteps, id: \.self) { q in
                    Button {
                        value.wrappedValue = max(0, value.wrappedValue + q)
                    } label: {
                        Text(q > 0 ? "+\(Int(q))" : "\(Int(q))")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.1))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
    
    // MARK: - 5. Database Alimenti Rapido
    
    private var foodDatabaseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CERCA NEL DATABASE ALIMENTI (39 ALIMENTI)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            
            TextField("Cerca es. Avena, Salmone, Yogurt...", text: $searchText)
                .padding(10)
                .background(Color(.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            if let food = selectedFood {
                let scaled = food.scaled(for: foodGrams)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(food.name).font(.subheadline.bold())
                        Spacer()
                        Text("\(Int(foodGrams))g").font(.subheadline.bold()).foregroundStyle(Theme.accentCyan)
                    }
                    
                    Slider(value: $foodGrams, in: 10...400, step: 5)
                    
                    HStack {
                        Text("\(Int(scaled.kcal)) kcal")
                            .font(.caption.bold())
                        Spacer()
                        Text("P: \(Int(scaled.protein))g • C: \(Int(scaled.carbs))g • G: \(Int(scaled.fat))g • Z: \(Int(scaled.sugars))g")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button {
                        applyFoodToMeal(food, grams: foodGrams)
                    } label: {
                        Text("Aggiungi al Pasto")
                            .font(.system(.caption, design: .rounded).bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Theme.accentEmerald)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(10)
                .background(Color(.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(filteredFoods.prefix(3)) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).font(.caption.bold())
                            Text(item.category).font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(Int(item.kcalPer100g)) kcal/100g")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedFood = item
                        foodGrams = item.defaultGrams
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - 6. Note e Sensazioni (In fondo con ampio spazio)
    
    private var notesAndSensationsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundStyle(Theme.accentCyan)
                Text("NOTE, SENSAZIONI E DIGESTIONE")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            
            TextField("Come ti senti dopo questo pasto? (es. Digestione ottima, energia costante, sazietà per 4 ore...)", text: $notesText, axis: .vertical)
                .lineLimit(4...10)
                .font(.system(.subheadline, design: .rounded))
                .padding(12)
                .background(Color(.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Sheet Dettaglio Preset
    
    private func presetPreviewSheet(_ preset: MealPreset) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Theme.accentEmerald.opacity(0.18))
                                .frame(width: 60, height: 60)
                            Image(systemName: preset.icon)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(Theme.accentEmerald)
                        }
                        
                        Text(preset.title)
                            .font(.system(.title3, design: .rounded).bold())
                        
                        Text(preset.subtitle)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 10)
                    
                    // Macro Pills
                    HStack(spacing: 10) {
                        macroPill(label: "Kcal", value: "\(Int(preset.kcal))", color: .orange)
                        macroPill(label: "Proteine", value: "\(Int(preset.protein))g", color: Theme.accentEmerald)
                        macroPill(label: "Carboidrati", value: "\(Int(preset.carbs))g", color: Theme.accentAmber)
                        macroPill(label: "Grassi", value: "\(Int(preset.fat))g", color: Theme.accentRose)
                        macroPill(label: "Zuccheri", value: "\(Int(preset.sugars))g", color: Theme.accentCyan)
                    }
                    
                    // Lista Ingredienti
                    VStack(alignment: .leading, spacing: 10) {
                        Text("COMPOSIZIONE & GRAMMI")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        VStack(spacing: 6) {
                            ForEach(preset.ingredients, id: \.self) { ing in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Theme.accentEmerald)
                                        .frame(width: 6, height: 6)
                                    Text(ing)
                                        .font(.system(.subheadline, design: .rounded))
                                    Spacer()
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Impatto Fisiologico
                    VStack(alignment: .leading, spacing: 6) {
                        Text("FOCUS FISIOLOGICO")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                        
                        Text(preset.physiologicalImpact)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Bottoni Azione
                    VStack(spacing: 12) {
                        Button {
                            // Salva subito
                            savePresetDirectly(preset)
                            selectedPresetForPreview = nil
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Conferma e Salva Subito")
                            }
                            .font(.system(.headline, design: .rounded).bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.emeraldGradient)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        
                        Button {
                            // Modifica nel form
                            loadPresetIntoForm(preset)
                            selectedPresetForPreview = nil
                        } label: {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                Text("Personalizza / Modifica Ingredienti")
                            }
                            .font(.system(.subheadline, design: .rounded).bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.secondary.opacity(0.12))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { selectedPresetForPreview = nil }
                }
            }
        }
    }
    
    private func macroPill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Logic & Actions
    
    private func startGeminiReasoningFlow() async {
        await MainActor.run {
            self.isGeminiThinking = true
            self.aiThinkingPhase = 0
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                self.gradientRotation = 360
            }
        }
        
        // Ciclo di pensiero simulato per mostrare i vari passaggi
        for phase in 0..<3 {
            try? await Task.sleep(nanoseconds: 700_000_000)
            await MainActor.run {
                self.aiThinkingPhase = phase + 1
            }
        }
        
        do {
            let res = try await gemini.analyzeMeal(prompt: aiPromptText)
            await MainActor.run {
                if let matched = MealType.allCases.first(where: { $0.rawValue.lowercased() == res.mealType.lowercased() }) {
                    selectedType = matched
                }
                descriptionText = res.foodDescription
                kcalValue = res.kcal
                proteinValue = res.proteinG
                carbsValue = res.carbsG
                fatValue = res.fatG
                sugarsValue = res.sugarsG
                notesText = res.notes
                isGeminiThinking = false
            }
        } catch {
            await MainActor.run {
                isGeminiThinking = false
            }
        }
    }
    
    private func loadPresetIntoForm(_ preset: MealPreset) {
        selectedType = preset.mealType
        descriptionText = preset.ingredients.joined(separator: ", ")
        kcalValue = preset.kcal
        proteinValue = preset.protein
        carbsValue = preset.carbs
        fatValue = preset.fat
        sugarsValue = preset.sugars
        notesText = preset.physiologicalImpact
    }
    
    private func savePresetDirectly(_ preset: MealPreset) {
        let entry = MealEntry(
            date: log.date,
            mealType: preset.mealType,
            title: preset.title,
            foodDescription: preset.ingredients.joined(separator: ", "),
            kcal: preset.kcal,
            proteinG: preset.protein,
            carbsG: preset.carbs,
            fatG: preset.fat,
            sugarsG: preset.sugars,
            notes: preset.physiologicalImpact,
            presetName: preset.title
        )
        entry.dailyLog = log
        log.meals.append(entry)
        
        lastSavedMealTitle = preset.title
        showingPostSaveAlert = true
    }
    
    private func applyFoodToMeal(_ food: FoodItem, grams: Double) {
        let scaled = food.scaled(for: grams)
        if descriptionText.isEmpty {
            descriptionText = "\(Int(grams))g \(food.name)"
        } else {
            descriptionText += ", \(Int(grams))g \(food.name)"
        }
        
        kcalValue += scaled.kcal
        proteinValue += scaled.protein
        carbsValue += scaled.carbs
        fatValue += scaled.fat
        sugarsValue += scaled.sugars
        
        selectedFood = nil
    }
    
    private func saveCurrentMeal() {
        if log.modelContext == nil {
            modelContext.insert(log)
        }
        let titleToSave = descriptionText.isEmpty ? selectedType.rawValue : descriptionText
        let entry = MealEntry(
            date: log.date,
            mealType: selectedType,
            title: selectedType.rawValue,
            foodDescription: titleToSave,
            kcal: kcalValue,
            proteinG: proteinValue,
            carbsG: carbsValue,
            fatG: fatValue,
            sugarsG: sugarsValue,
            notes: notesText
        )
        entry.dailyLog = log
        log.meals.append(entry)
        modelContext.insert(entry)
        try? modelContext.save()
        
        lastSavedMealTitle = titleToSave
        showingPostSaveAlert = true
    }
    
    private func resetFormForNextMeal() {
        descriptionText = ""
        aiPromptText = ""
        kcalValue = 0
        proteinValue = 0
        carbsValue = 0
        fatValue = 0
        sugarsValue = 0
        notesText = ""
        selectedFood = nil
        // Avanza automaticamente al prossimo tipo logico di pasto
        switch selectedType {
        case .colazione: selectedType = .spuntino
        case .spuntino, .snack: selectedType = .pranzo
        case .pranzo: selectedType = .spuntino
        case .cena: selectedType = .bevande
        case .bevande: selectedType = .colazione
        }
    }
}
