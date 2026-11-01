//
//  ProfileView.swift
//  MacroBara
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ProfileView: View {
    var isEmbeddedInTab: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    
    @State private var gemini = GeminiService.shared
    @State private var syncService = ICloudSyncService.shared
    @State private var showingFolderPicker: Bool = false
    
    // Form States
    @State private var firstName: String = "Marco"
    @State private var lastName: String = "Rossi"
    @State private var ageText: String = "25"
    @State private var heightText: String = "180"
    @State private var gender: String = "Uomo"
    @State private var jobActivity: String = "Sedentario (Ufficio)"
    
    @State private var startWeightText: String = "89.0"
    @State private var currentWeightText: String = "87.9"
    @State private var targetWeightText: String = "78.0"
    @State private var normopesoWeightText: String = "80.7"
    
    @State private var targetKcalText: String = "1600"
    @State private var targetProteinText: String = "130"
    @State private var targetCarbsText: String = "170"
    @State private var targetFatText: String = "50"
    @State private var targetSugarText: String = "40"
    @State private var targetWaterText: String = "2.5"
    
    @State private var showingSavedAlert: Bool = false
    @State private var showingResetConfirmation: Bool = false
    
    private var currentProfile: UserProfile {
        profiles.first ?? UserProfile()
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Header Avatar & Stato
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Theme.coralTerracotta)
                                .frame(width: 64, height: 64)
                            Image("CapybaraMascot")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 48, height: 48)
                                .clipShape(Circle())
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(firstName) \(lastName)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text("Percorso Metabolico • MacroBara Pro")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.secondary)
                            Text("Versione App Store Ready 1.0 (iOS 27)")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.coralTerracotta)
                        }
                    }
                    .padding(.vertical, 6)
                }
                
                // 1. Dati Personali
                Section("Dati Personali & Anagrafica") {
                    HStack {
                        Text("Nome")
                        Spacer()
                        TextField("Nome", text: $firstName)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Cognome")
                        Spacer()
                        TextField("Cognome", text: $lastName)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Età")
                        Spacer()
                        TextField("Età", text: $ageText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Altezza (cm)")
                        Spacer()
                        TextField("Altezza cm", text: $heightText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Picker("Sesso Biologico", selection: $gender) {
                        Text("Uomo").tag("Uomo")
                        Text("Donna").tag("Donna")
                    }
                    
                    Picker("Attività Lavorativa", selection: $jobActivity) {
                        Text("Sedentario (Ufficio / PC)").tag("Sedentario (Ufficio)")
                        Text("In piedi / Camminata moderata").tag("In piedi (Moderato)")
                        Text("Lavoro Fisico / Attivo").tag("Lavoro Fisico (Attivo)")
                    }
                }
                
                // 2. Peso & Obiettivi
                Section("Obiettivi di Peso (kg)") {
                    HStack {
                        Text("Peso di Partenza (W0)")
                        Spacer()
                        TextField("89.0", text: $startWeightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Peso Attuale")
                        Spacer()
                        TextField("87.9", text: $currentWeightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Soglia Normopeso")
                        Spacer()
                        TextField("80.7", text: $normopesoWeightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Target Finale")
                        Spacer()
                        TextField("78.0", text: $targetWeightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                // 3. Target Nutrizionali & Metabolici
                Section("Target Energetici & Macronutrienti") {
                    HStack {
                        Text("Calorie Giornaliere (kcal)")
                        Spacer()
                        TextField("1600", text: $targetKcalText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Proteine (g)")
                        Spacer()
                        TextField("130", text: $targetProteinText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Carboidrati (g)")
                        Spacer()
                        TextField("170", text: $targetCarbsText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Grassi Max (g)")
                        Spacer()
                        TextField("50", text: $targetFatText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Zuccheri Max (<40g)")
                        Spacer()
                        TextField("40", text: $targetSugarText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Idratazione Acqua (L)")
                        Spacer()
                        TextField("2.5", text: $targetWaterText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                // 4. Sincronizzazione iCloud & Assistente AI
                Section("Sincronizzazione iCloud & Assistente AI") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(
                                syncService.isFolderLinked ? "Cartella iCloud Collegata" : "Cartella iCloud Non Collegata",
                                systemImage: syncService.isFolderLinked ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                            )
                            .foregroundStyle(syncService.isFolderLinked ? Color(red: 16/255, green: 185/255, blue: 129/255) : Color.orange)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            
                            Spacer()
                            
                            if let name = syncService.configuredFolderName {
                                Text(name)
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Text("Consente a MacroBara di salvare passi e calorie (ultimi 14 giorni) su iCloud Drive/Automazione per la sincronizzazione istantanea con l'assistente Mac.")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    Button {
                        showingFolderPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "folder.badge.gearshape")
                            Text(syncService.isFolderLinked ? "Cambia Cartella iCloud" : "Collega Cartella Automazione")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                    }
                    
                    Button {
                        Task {
                            await syncService.exportHealthDataToICloud()
                        }
                    } label: {
                        HStack {
                            if syncService.isSyncing {
                                ProgressView()
                                    .padding(.trailing, 4)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text("Esporta Dati Salute Ora (14 Giorni)")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                    }
                    .disabled(syncService.isSyncing)
                    
                    if let lastSync = syncService.lastSyncDate {
                        HStack {
                            Text("Ultimo export:")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(lastSync, style: .date)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(lastSync, style: .time)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if !syncService.statusMessage.isEmpty {
                        Text(syncService.statusMessage)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(Theme.coralTerracotta)
                    }
                }
                
                // 5. Intelligenza Artificiale Gemini
                Section("Motore IA Gemini") {
                    SecureField("Chiave API Google AI Studio", text: Bindable(gemini).apiKey)
                        .font(.system(.body, design: .monospaced))
                    
                    Picker("Versione Modello", selection: Bindable(gemini).selectedModel) {
                        ForEach(GeminiModelOption.allCases) { model in
                            Text(model.displayName).tag(model)
                        }
                    }
                }
                
                // 5. Salva & Azioni
                Section {
                    Button {
                        saveProfile()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Salva Modifiche Profilo")
                                .font(.system(.body, design: .rounded).bold())
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Theme.coralTerracotta)
                }
            }
            .navigationTitle("Profilo Utente")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaPadding(.bottom, isEmbeddedInTab ? 100 : 0)
            .toolbar {
                if !isEmbeddedInTab {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Chiudi") {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEmbeddedInTab ? "Salva" : "Fatto") {
                        saveProfile()
                        if !isEmbeddedInTab {
                            dismiss()
                        }
                    }
                    .bold()
                }
            }
            .alert("Profilo Aggiornato! ✅", isPresented: $showingSavedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Tutti i parametri biometrici, calorie e macro target sono stati salvati.")
            }
            .fileImporter(
                isPresented: $showingFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        syncService.linkFolder(url: url)
                    }
                case .failure(let error):
                    syncService.statusMessage = "Errore selezione cartella: \(error.localizedDescription)"
                }
            }
            .onAppear {
                loadProfile()
            }
        }
    }
    
    private func loadProfile() {
        let p = currentProfile
        let nameComponents = p.name.split(separator: " ")
        if nameComponents.count >= 2 {
            firstName = String(nameComponents[0])
            lastName = String(nameComponents.dropFirst().joined(separator: " "))
        } else {
            firstName = p.name
        }
        
        ageText = "\(p.age)"
        heightText = "\(Int(p.heightCm))"
        startWeightText = String(format: "%.1f", p.startWeightKg)
        currentWeightText = String(format: "%.1f", p.currentWeightKg)
        targetWeightText = String(format: "%.1f", p.targetWeightKg)
        normopesoWeightText = String(format: "%.1f", p.normopesoMaxWeightKg)
        
        targetKcalText = "\(Int(p.targetKcal))"
        targetProteinText = "\(Int(p.targetProteinG))"
        targetCarbsText = "\(Int(p.targetCarbsG))"
        targetFatText = "\(Int(p.targetFatG))"
        targetSugarText = "\(Int(p.targetSugarMaxG))"
        targetWaterText = String(format: "%.1f", p.targetWaterL)
    }
    
    private func saveProfile() {
        let p = currentProfile
        p.name = "\(firstName.trimmingCharacters(in: .whitespaces)) \(lastName.trimmingCharacters(in: .whitespaces))".trimmingCharacters(in: .whitespaces)
        p.age = Int(ageText) ?? p.age
        p.heightCm = Double(heightText) ?? p.heightCm
        
        if let sw = Double(startWeightText.replacingOccurrences(of: ",", with: ".")) { p.startWeightKg = sw }
        if let cw = Double(currentWeightText.replacingOccurrences(of: ",", with: ".")) { p.currentWeightKg = cw }
        if let tw = Double(targetWeightText.replacingOccurrences(of: ",", with: ".")) { p.targetWeightKg = tw }
        if let nw = Double(normopesoWeightText.replacingOccurrences(of: ",", with: ".")) { p.normopesoMaxWeightKg = nw }
        
        if let tk = Double(targetKcalText) { p.targetKcal = tk }
        if let tp = Double(targetProteinText) { p.targetProteinG = tp }
        if let tc = Double(targetCarbsText) { p.targetCarbsG = tc }
        if let tf = Double(targetFatText) { p.targetFatG = tf }
        if let ts = Double(targetSugarText) { p.targetSugarMaxG = ts }
        if let twat = Double(targetWaterText.replacingOccurrences(of: ",", with: ".")) { p.targetWaterL = twat }
        
        try? modelContext.save()
        showingSavedAlert = true
    }
}
