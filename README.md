# 🦫 MacroBara

> **A Chill, Zen-Driven Nutrition & Metabolic Health Companion for iOS**  
> *Sviluppata nativamente in Swift 6, SwiftUI, SwiftData, HealthKit, Swift Charts e WidgetKit.*

---

## 📖 Indice
1. [Perché nasce MacroBara?](#-perché-nasce-macrobara)
2. [I Pilastri Scientifici del Percorso](#-i-pilastri-scientifici-del-percorso)
3. [Funzionalità Chiave](#-funzionalità-chiave)
4. [Architettura del Progetto](#-architettura-del-progetto)
5. [Struttura delle Cartelle](#-struttura-delle-cartelle)
6. [Tech Stack & Requisiti](#-tech-stack--requisiti)
7. [Installazione e Configurazione](#-installazione-e-configurazione)
8. [Privacy & Sicurezza](#-privacy--sicurezza)
9. [Licenza](#-licenza)

---

## 🎯 Perché nasce MacroBara?

La stragrande maggioranza delle app di nutrizione sul mercato (*MyFitnessPal*, *YAZIO*, *Lose It!*) condividono gli stessi difetti strutturali:
- **Interfacce ansiogene**: allarmi visivi rossi invasivi, contatori punitivi e paywall aggressivi.
- **Formule caloriche statiche e irrealistiche**: algoritmi che ignorano il dispendio energetico reale della giornata.
- **Mancanza di focus metabolico**: contano solo le calorie totali ("CICO" ingenuo), trascurando l'impatto glicemico, la sazietà e l'infiammazione provocata dagli zuccheri semplici.

**MacroBara** ribalta questo paradigma ispirandosi alla serenità del **Capibara**, il mammifero più rilassato al mondo. L'obiettivo è trasformare il percorso di ricomposizione corporea e dimagrimento (partendo da una condizione di sovrappeso a **~89 kg** fino al traguardo del **Normopeso a 80.7 kg** e al target finale di **78 kg**) in un processo **sostenibile, scientifico, privo di sensi di colpa e incentrato sulla lucidità metabolica**.

---

## 🔬 I Pilastri Scientifici del Percorso

MacroBara è costruita attorno a principi validati dalla fisiologia nutrizionale moderna:

1. **Deficit Energetico Controllato (~500 kcal/die)**:
   - Un deficit moderato e costante garantisce la massima perdita di massa grassa preservando la massa magra (LBM), minimizzando il crollo metabolico e la perdita di forza.
2. **Integrazione Apple Watch in Tempo Reale (Dynamic TDEE)**:
   - Invece di usare formule matematiche teoriche (Harris-Benedict fissa), il budget calorico si sincronizza con **Apple HealthKit**:
     $$\text{Budget Giornaliero} = \text{BMR (Basale)} + \text{Active Energy (Movimento reale)} - 500\text{ kcal}$$
   - Se ti muovi di più, il budget aumenta automaticamente; nei giorni di riposo, si adatta coerentemente.
3. **Tetto agli Zuccheri Semplici (< 40g/die)**:
   - Monitoraggio stringente del carico glicemico. Mantenere gli zuccheri liberi sotto i 40g previene picchi insulinici seguiti da ipoglicemie reattive ("Sugar Crash"), responsabili di fame compulsiva e sonnolenza pomeridiana.
4. **Target Proteico Elevato (130–150g/die)**:
   - Saturazione dei recettori della sazietà (ormoni GLP-1, PYY) ed effetto termico del cibo (TEF).
5. **24 Smart Swaps Scientifici**:
   - Una guida integrata per sostituire alimenti ad alta densità energetica e poveri di nutrienti con varianti identiche al palato ma ricche di proteine, fibre e micronutrienti (es. da yogurt zuccherato a Fage 0% + frutti di bosco; da farina bianca a fiocchi d'avena).
6. **Mindful Feedback Fisiologico**:
   - Oltre ai macronutrienti, ogni pasto permette di registrare sazietà, digeribilità e sensazione post-prandiale, educando l'utente a riconoscere i segnali del proprio corpo.

---

## ✨ Funzionalità Chiave

### 1. 📊 Bento Grid Dashboard
- **Anelli Macro Dinamici**: Visualizzazione circolare fluida per Proteine, Carboidrati e Grassi con micro-animazioni.
- **Caloric Deficit Gauge**: Bilancio energetico istantaneo (Entrate vs TDEE reale da Apple Watch).
- **Sugar Safety Alert**: Indicatore dinamico del tetto zuccheri che cambia gradualmente tonalità avvisando dell'impatto glicemico.
- **Daily Tier List ($F \rightarrow A^{+++}$)**: Algoritmo intelligente che valuta la qualità nutrizionale complessiva del giorno basandosi su aderenza calorica, zuccheri e target proteico.

### 2. ⚡ AI Smart Meal Logging & Quick Presets
- **Natural Language & AI Parser**: Supporto per trascrizione e parsing tramite le API di Google Gemini (con modelli multimodali 3.8 Flash e fallback locale offline basato su pattern euristici).
- **Preset Rapidi in 1-Tap**: Accesso istantaneo ai pasti tipici (es. *Porridge Proteico Avena & Whey*, *Snack Greco & Mirtilli*).
- **Scanner Nutrizionale Manuale**: Interfaccia ottimizzata per inserire o rettificare porzioni e macro in pochi secondi.

### 3. 📈 Swift Charts Weight Timeline & Predizioni
- **Traiettoria Dinamica Bento Yellow**: Grafico a linee e area basato sul framework nativo Apple Swift Charts.
- **Doppia Milestone Visiva**:
  - Linea guida per **Normopeso (80.7 kg)** (BMI < 25 per 180 cm).
  - Traguardo finale (78 kg).
- **Modello Previsionale Matematico**: Proiezione futura della curva calcolata integrando il deficit energetico medio registrato e il trend storico delle misurazioni.
- **Gestione Completa Misurazioni**: Possibilità di aggiungere pesate con data retroattiva o eliminare voci inserite per errore, con riadattamento istantaneo delle curve.

### 4. 🔀 Smart Swaps Hub
- Catalogo interattivo di 24 sostituzioni alimentari strategiche per tagliare calorie e zuccheri aumentando la sazietà, catalogate per colazione, spuntini, pranzo e cene fuori.

### 5. 📱 WidgetKit Home Screen
- Widget nativo iOS per visualizzare a colpo d'occhio calorie rimanenti, avanzamento proteine e la mascotte Capibara reattiva direttamente dalla schermata iniziale di iPhone.

---

## 🏛️ Architettura del Progetto

Il progetto segue scrupolosamente l'architettura **MVVM (Model-View-ViewModel)** unita ai paradigmi reattivi moderni di SwiftUI:

```
                  ┌──────────────────────┐
                  │    Apple HealthKit   │
                  │  (TDEE, Steps, Weight)│
                  └──────────┬───────────┘
                             │
                             ▼
┌─────────────────┐   ┌──────────────────────┐   ┌─────────────────┐
│   SwiftData /   │◄─►│   HealthKitManager   │◄─►│   Google Gemini │
│  Local Storage  │   │   & Services         │   │   AI API Service│
└────────┬────────┘   └──────────┬───────────┘   └─────────────────┘
         │                       │
         ▼                       ▼
┌────────────────────────────────────────────┐
│                 ViewModels                 │
│  (DashboardVM, NutritionVM, ProgressVM)   │
└─────────────────────┬──────────────────────┘
                      │ State Binding (@Observable / @StateObject)
                      ▼
┌────────────────────────────────────────────┐
│              SwiftUI Views                 │
│  (Dashboard, AddMeal, Progress, Swaps)     │
└─────────────────────┬──────────────────────┘
                      │ Shared Container
                      ▼
┌────────────────────────────────────────────┐
│          WidgetKit Extension               │
│          (MacroBara Home Widget)           │
└────────────────────────────────────────────┘
```

- **Clean Architecture & Separation of Concerns**: Logica di business confinata nei `Services` e `ViewModels`.
- **Offline-First & Local Persistence**: Tutte le entrate vengono memorizzate localmente con `SwiftData`, garantendo reattività istantanea e pieno funzionamento offline.
- **Glassmorphism 2.0 Design System**: Utilizzo dei materiali nativi Apple (`.ultraThinMaterial`), sfocature gaussiane in tempo reale e contrasti adattivi per Dark Mode e Light Mode.

---

## 📂 Struttura delle Cartelle

```text
MacroBara/
├── MacroBara/
│   ├── App/
│   │   └── MacroBaraApp.swift            # Entry point dell'applicazione
│   ├── Models/                           # Modelli dati principali
│   │   ├── Meal.swift                    # Pasti e alimenti
│   │   ├── UserProfile.swift             # Dati utente, TDEE e target
│   │   ├── WeightEntry.swift             # Storico pesate e milestone
│   │   ├── SmartSwap.swift               # Catalogo sostituzioni sazianti
│   │   └── DailyTier.swift               # Algoritmo Tier List (F -> A+++)
│   ├── ViewModels/                       # Logica applicativa e reattività
│   │   ├── DashboardViewModel.swift      # Gestione dashboard e anelli macro
│   │   ├── NutritionViewModel.swift      # Calcolo nutrienti e pasti
│   │   └── ProgressViewModel.swift       # Gestione trend peso e predizione
│   ├── Views/                            # Interfacce SwiftUI
│   │   ├── Dashboard/                    # Dashboard Bento Grid principale
│   │   ├── AddMeal/                      # Log pasti, AI Smart parser, scanner
│   │   ├── Progress/                     # Swift Charts, timeline e pesate
│   │   ├── Swaps/                        # Vista interattiva Smart Swaps
│   │   ├── Profile/                      # Gestione profilo, TDEE e obiettivi
│   │   └── Components/                   # Componenti riutilizzabili (GlassCard, ecc.)
│   ├── Services/                         # Servizi di background e integrazioni
│   │   ├── HealthKitManager.swift        # Sincronizzazione Apple Watch / Health
│   │   ├── GeminiAPIService.swift        # AI Parsing con fallback offline
│   │   └── DataImporter.swift            # Inizializzazione dati e preset
│   └── Resources/
│       ├── Assets.xcassets               # Icone vettoriali, colori e mascotte
│       └── initial_history.json          # Template iniziale anonimizzato
├── MacroBaraWidgetExtension/             # Estensione WidgetKit per Home Screen
│   ├── MacroBaraWidget.swift             # TimelineProvider e UI del Widget
│   └── Assets.xcassets                   # Risorse grafiche del widget
├── MacroBara.xcodeproj                   # Progetto Xcode configurato
├── LICENSE                               # Licenza open-source MIT
└── README.md                             # Documentazione completa
```

---

## 💻 Tech Stack & Requisiti

- **Linguaggio**: Swift 6
- **Framework Principale**: SwiftUI (iOS 17.0+)
- **Persistenza**: SwiftData
- **Grafici**: Swift Charts
- **Salute**: Apple HealthKit (`HKHealthStore`)
- **Estensioni**: WidgetKit (Home Screen widgets)
- **AI / NLP**: Google Gemini API (3.8 Flash / Pro) con parser euristico di riserva
- **Requisiti di Sistema**:
  - Mac con macOS 14 Sonoma o successivo
  - Xcode 16.0 o successivo
  - Dispositivo fisico o Simulatore con iOS 17.0+

---

## 🚀 Installazione e Configurazione

1. **Clona la repository**:
   ```bash
   git clone https://github.com/Nicolasch9/MacroBara.git
   cd MacroBara
   ```

2. **Apri il progetto in Xcode**:
   ```bash
   open MacroBara.xcodeproj
   ```

3. **Configura il Team di Sviluppo**:
   - In Xcode, seleziona il target principale `MacroBara` in *Signing & Capabilities*.
   - Seleziona il tuo **Personal Team** gratuito o Developer Account.
   - Ripeti la selezione per il target `MacroBaraWidgetExtension` mantenendo coerente il Bundle Identifier.

4. **Esegui l'app**:
   - Seleziona il tuo iPhone collegato (oppure un simulatore iPhone 15/16).
   - Premi `Cmd + R` per compilare ed eseguire.

---

## 🛡️ Privacy & Sicurezza

- **Zero Tracker / Zero Pubblicità**: Nessun framework di terze parti per analytics o ads (Google Analytics, Firebase o Meta SDK non sono presenti).
- **Archiviazione Locale al 100%**: Tutti i registri alimentari, i pesi e i parametri biometrici risiedono esclusivamente sul dispositivo.
- **Integrazione Sanitaria Protetta**: L'accesso ai dati di HealthKit richiede l'autorizzazione esplicita dell'utente e non trasmette mai dati al di fuori del sistema Apple.
- **Repository Pubblica Anonimizzata**: Nessun identificatore personale, email, token API o credenziale privata è presente in questo codice sorgente.

---

## 📄 Licenza

Distribuito sotto licenza **MIT**. Consulta il file [LICENSE](LICENSE) per ulteriori informazioni.
