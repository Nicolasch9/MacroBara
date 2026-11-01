//
//  Theme.swift
//  MacroBara
//

import SwiftUI

enum Theme {
    static let accentEmerald = Color(red: 16/255, green: 185/255, blue: 129/255)
    static let accentCyan = Color(red: 6/255, green: 182/255, blue: 212/255)
    static let accentAmber = Color(red: 245/255, green: 158/255, blue: 11/255)
    static let accentRose = Color(red: 244/255, green: 63/255, blue: 94/255)
    static let accentPurple = Color(red: 139/255, green: 92/255, blue: 246/255)
    
    // Stile Hero Espresso & Terracotta (Ispirato a Claude Design)
    static let heroEspressoDark = Color(red: 24/255, green: 16/255, blue: 14/255)
    static let heroEspressoLight = Color(red: 48/255, green: 32/255, blue: 27/255)
    static let coralTerracotta = Color(red: 232/255, green: 105/255, blue: 75/255)
    static let coralTerracottaLight = Color(red: 252/255, green: 238/255, blue: 234/255)
    static let pageBackground = Color(red: 246/255, green: 246/255, blue: 248/255)
    
    static let heroEspressoGradient = LinearGradient(
        colors: [heroEspressoLight, heroEspressoDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let darkBackground = Color(red: 10/255, green: 15/255, blue: 28/255)
    static let lightBackground = Color(red: 245/255, green: 247/255, blue: 250/255)
    
    static let emeraldGradient = LinearGradient(
        colors: [accentEmerald, Color(red: 5/255, green: 150/255, blue: 105/255)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cyanGradient = LinearGradient(
        colors: [accentCyan, Color(red: 14/255, green: 116/255, blue: 144/255)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let amberGradient = LinearGradient(
        colors: [accentAmber, Color(red: 217/255, green: 119/255, blue: 6/255)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let purpleGradient = LinearGradient(
        colors: [accentPurple, Color(red: 109/255, green: 40/255, blue: 217/255)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
