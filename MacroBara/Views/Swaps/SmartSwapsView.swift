//
//  SmartSwapsView.swift
//  MacroBara
//

import SwiftUI

struct SmartSwapsView: View {
    @State private var selectedCategory: String = "Tutti"
    @State private var searchText: String = ""
    
    private let categories = ["Tutti", "Colazione", "Bevande", "Pranzo / Cena", "Snack"]
    
    private var filteredSwaps: [SmartSwap] {
        SmartSwap.defaults.filter { swap in
            let matchCategory = (selectedCategory == "Tutti") || (swap.category.contains(selectedCategory))
            let matchSearch = searchText.isEmpty ||
                swap.originalFood.localizedCaseInsensitiveContains(searchText) ||
                swap.swapFood.localizedCaseInsensitiveContains(searchText) ||
                swap.whyItWorks.localizedCaseInsensitiveContains(searchText) ||
                swap.metabolicBenefit.localizedCaseInsensitiveContains(searchText)
            return matchCategory && matchSearch
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header filosofico
                    GlassCard {
                        HStack(spacing: 14) {
                            Text("🔄")
                                .font(.system(size: 32))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Hub Sostituzioni Intelligenti")
                                    .font(.system(.headline, design: .rounded).bold())
                                Text("Nessuna rinuncia: sostituisci gli alimenti ad alto indice glicemico con cibi nutrienti ad alta sazietà.")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // Categorie chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { cat in
                                Button {
                                    selectedCategory = cat
                                } label: {
                                    Text(cat)
                                        .font(.system(.caption, design: .rounded).bold())
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(selectedCategory == cat ? Theme.coralTerracotta : Color.white)
                                        .foregroundStyle(selectedCategory == cat ? .white : .primary)
                                        .clipShape(Capsule())
                                        .shadow(color: Color.black.opacity(selectedCategory == cat ? 0.12 : 0.04), radius: 6, x: 0, y: 2)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                    }
                    
                    // Lista Swaps
                    ForEach(filteredSwaps) { swap in
                        swapCard(swap)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .searchable(text: $searchText, prompt: "Cerca alimenti da sostituire...")
            .background(Theme.pageBackground.ignoresSafeArea())
            .navigationTitle("Sostituzioni")
        }
    }
    
    private func swapCard(_ swap: SmartSwap) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(swap.category.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accentEmerald)
                    Spacer()
                    Text(swap.metabolicBenefit)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.accentCyan)
                }
                
                // Originale vs Swap
                VStack(spacing: 8) {
                    HStack(alignment: .top) {
                        Text("❌ Invece di:")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.accentRose)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(swap.originalFood)
                                .font(.system(.caption, design: .rounded).bold())
                            Text("\(Int(swap.originalKcal)) kcal • \(Int(swap.originalSugars))g zuccheri")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                    
                    HStack(alignment: .top) {
                        Text("✅ Prova:")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.accentEmerald)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(swap.swapFood)
                                .font(.system(.caption, design: .rounded).bold())
                            Text("\(Int(swap.swapKcal)) kcal • \(Int(swap.swapSugars))g zuccheri • \(Int(swap.swapProtein))g proteine")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Spiegazione fisiologica
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.accentAmber)
                    Text(swap.whyItWorks)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
