//
//  FoodItem.swift
//  MacroBara
//

import Foundation

struct FoodItem: Identifiable, Hashable, Codable {
    var id: String { name }
    var name: String
    var category: String
    var defaultGrams: Double
    var kcalPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var sugarsPer100g: Double
    var notes: String
    
    func scaled(for grams: Double) -> (kcal: Double, protein: Double, carbs: Double, fat: Double, sugars: Double) {
        let factor = grams / 100.0
        return (
            (kcalPer100g * factor * 10).rounded() / 10,
            (proteinPer100g * factor * 10).rounded() / 10,
            (carbsPer100g * factor * 10).rounded() / 10,
            (fatPer100g * factor * 10).rounded() / 10,
            (sugarsPer100g * factor * 10).rounded() / 10
        )
    }
}

extension FoodItem {
    static var database: [FoodItem] = [
        FoodItem(name: "Macinato di manzo / vitello (crudo)", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 215.0, proteinPer100g: 21.0, carbsPer100g: 0.0, fatPer100g: 14.5, sugarsPer100g: 0.0, notes: "Carne bovina macinata scelta"),
        FoodItem(name: "Pasta formato anelletti (cruda)", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 355.0, proteinPer100g: 12.5, carbsPer100g: 73.0, fatPer100g: 1.5, sugarsPer100g: 1.0, notes: "Pasta secca di semola corta"),
        FoodItem(name: "Pasta di semola (cruda)", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 355.0, proteinPer100g: 12.5, carbsPer100g: 73.0, fatPer100g: 1.5, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Pasta con pomodoro e filo d'olio", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 380.0, proteinPer100g: 11.0, carbsPer100g: 62.0, fatPer100g: 8.0, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Riso basmati/arborio (crudo)", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 360.0, proteinPer100g: 7.0, carbsPer100g: 78.0, fatPer100g: 0.8, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Riso con verdure e olio", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 370.0, proteinPer100g: 8.0, carbsPer100g: 65.0, fatPer100g: 7.5, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Pane comune / ciabatta", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 135.0, proteinPer100g: 4.5, carbsPer100g: 27.0, fatPer100g: 0.5, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Pane integrale", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 115.0, proteinPer100g: 4.0, carbsPer100g: 22.0, fatPer100g: 1.0, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Petto di pollo ai ferri", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 165.0, proteinPer100g: 34.5, carbsPer100g: 0.0, fatPer100g: 2.0, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Fesa di tacchino ai ferri", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 160.0, proteinPer100g: 36.0, carbsPer100g: 0.0, fatPer100g: 1.8, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Bistecca di manzo magro", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 190.0, proteinPer100g: 31.5, carbsPer100g: 0.0, fatPer100g: 6.5, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Salmone fresco al forno / piastra", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 280.0, proteinPer100g: 30.0, carbsPer100g: 0.0, fatPer100g: 17.0, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Filetto di merluzzo o orata", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 150.0, proteinPer100g: 31.0, carbsPer100g: 0.0, fatPer100g: 2.2, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Tonno al naturale (sgocciolato)", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 60.0, proteinPer100g: 14.0, carbsPer100g: 0.0, fatPer100g: 0.5, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Tonno sott'olio (sgocciolato)", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 105.0, proteinPer100g: 13.0, carbsPer100g: 0.0, fatPer100g: 5.5, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Uova intere (medie)", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 140.0, proteinPer100g: 12.5, carbsPer100g: 0.6, fatPer100g: 9.8, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Albume d'uovo", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 50.0, proteinPer100g: 11.0, carbsPer100g: 0.7, fatPer100g: 0.2, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Mozzarella vaccina", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 250.0, proteinPer100g: 18.0, carbsPer100g: 1.0, fatPer100g: 19.0, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Mozzarella light", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 165.0, proteinPer100g: 20.0, carbsPer100g: 1.5, fatPer100g: 9.0, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Fiocchi di latte", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 140.0, proteinPer100g: 18.0, carbsPer100g: 4.5, fatPer100g: 4.5, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Parmigiano / Grana grattugiato", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 40.0, proteinPer100g: 3.3, carbsPer100g: 0.0, fatPer100g: 2.8, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Legumi cotti (ceci, lenticchie, fagioli)", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 160.0, proteinPer100g: 11.0, carbsPer100g: 24.0, fatPer100g: 1.5, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Olio extravergine d'oliva (EVO)", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 90.0, proteinPer100g: 0.0, carbsPer100g: 0.0, fatPer100g: 10.0, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Insalata mista / Verdure a foglia", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 25.0, proteinPer100g: 2.0, carbsPer100g: 3.0, fatPer100g: 0.3, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Pomodori da insalata", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 36.0, proteinPer100g: 1.8, carbsPer100g: 7.0, fatPer100g: 0.4, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Zucchine / Finocchi / Cetrioli", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 30.0, proteinPer100g: 2.5, carbsPer100g: 4.0, fatPer100g: 0.2, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Mela / Pera / Arancia", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 80.0, proteinPer100g: 0.6, carbsPer100g: 20.0, fatPer100g: 0.3, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Banana", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 105.0, proteinPer100g: 1.3, carbsPer100g: 25.0, fatPer100g: 0.3, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Frutta secca (noci/mandorle)", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 125.0, proteinPer100g: 4.0, carbsPer100g: 2.0, fatPer100g: 11.0, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Yogurt Greco 0% grassi", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 85.0, proteinPer100g: 15.0, carbsPer100g: 5.5, fatPer100g: 0.0, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Yogurt bianco intero", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 85.0, proteinPer100g: 4.5, carbsPer100g: 6.0, fatPer100g: 4.5, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Latte parzialmente scremato", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 95.0, proteinPer100g: 6.6, carbsPer100g: 10.0, fatPer100g: 3.2, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Biscotti frollini", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 180.0, proteinPer100g: 3.0, carbsPer100g: 28.0, fatPer100g: 6.5, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Fette biscottate con marmellata", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 160.0, proteinPer100g: 3.5, carbsPer100g: 32.0, fatPer100g: 1.5, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Caffè espresso amaro", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 2.0, proteinPer100g: 0.2, carbsPer100g: 0.3, fatPer100g: 0.0, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Caffè espresso con 1 cucchiaino di zucchero", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 22.0, proteinPer100g: 0.2, carbsPer100g: 5.3, fatPer100g: 0.0, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Bibita gassata zuccherata (es. Cola normale)", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 140.0, proteinPer100g: 0.0, carbsPer100g: 35.0, fatPer100g: 0.0, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Bibita Zero / Light", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 1.0, proteinPer100g: 0.0, carbsPer100g: 0.0, fatPer100g: 0.0, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Birra chiara 4.5%", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 140.0, proteinPer100g: 1.5, carbsPer100g: 10.0, fatPer100g: 0.0, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Vino rosso / bianco", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 95.0, proteinPer100g: 0.0, carbsPer100g: 3.0, fatPer100g: 0.0, sugarsPer100g: 0.0, notes: ""),
        FoodItem(name: "Pizza Margherita", category: "Alimenti", defaultGrams: 100.0, kcalPer100g: 850.0, proteinPer100g: 32.0, carbsPer100g: 125.0, fatPer100g: 24.0, sugarsPer100g: 0.0, notes: ""),
    ]
}
