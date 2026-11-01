//
//  TierBadgeView.swift
//  MacroBara
//

import SwiftUI

struct TierBadgeView: View {
    var grade: String
    var color: Color
    var size: CGFloat = 44
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.6), lineWidth: 1.5)
                )
                .shadow(color: color.opacity(0.25), radius: 8, x: 0, y: 3)
            
            Text(grade)
                .font(.system(size: size * 0.45, weight: .black, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(width: size * 1.5, height: size)
    }
}
