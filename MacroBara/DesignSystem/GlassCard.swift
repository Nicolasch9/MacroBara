//
//  GlassCard.swift
//  MacroBara
//

import SwiftUI

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 24
    var padding: CGFloat = 18
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 24, padding: CGFloat = 18) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}

struct GlassCard<Content: View>: View {
    var cornerRadius: CGFloat = 24
    var padding: CGFloat = 18
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        content()
            .glassCard(cornerRadius: cornerRadius, padding: padding)
    }
}
