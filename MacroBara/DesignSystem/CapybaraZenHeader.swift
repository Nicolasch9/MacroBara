//
//  CapybaraZenHeader.swift
//  MacroBara
//

import SwiftUI

struct CapybaraZenHeader: View {
    var title: String = "MacroBara"
    var subtitle: String = "Calma, costanza e disciplina zen."
    var iconName: String = "leaf.circle.fill"
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.emeraldGradient.opacity(0.15))
                    .frame(width: 56, height: 56)
                    .shadow(color: Theme.accentEmerald.opacity(0.35), radius: 10, x: 0, y: 4)
                
                Image("CapybaraMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(title)
                        .font(.system(.title3, design: .rounded).bold())
                    
                    Spacer()
                    
                    Text("LIVE")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.accentEmerald.opacity(0.18))
                        .foregroundStyle(Theme.accentEmerald)
                        .clipShape(Capsule())
                }
                
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .glassCard(cornerRadius: 18, padding: 14)
    }
}
