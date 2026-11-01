//
//  SmartSwap.swift
//  MacroBara
//

import Foundation

struct SmartSwap: Identifiable, Hashable {
    var id: String { originalFood }
    var category: String
    var originalFood: String
    var swapFood: String
    var originalKcal: Double
    var swapKcal: Double
    var originalSugars: Double
    var swapSugars: Double
    var originalProtein: Double
    var swapProtein: Double
    var metabolicBenefit: String
    var whyItWorks: String
    
    var kcalSaved: Double {
        originalKcal - swapKcal
    }
    
    var sugarSaved: Double {
        originalSugars - swapSugars
    }
    
    var proteinGained: Double {
        swapProtein - originalProtein
    }
}

extension SmartSwap {
    static let defaults: [SmartSwap] = [
        // MARK: - 1. Colazione (6 Sostituzioni)
        SmartSwap(
            category: "Colazione",
            originalFood: "Fette biscottate classiche con marmellata zuccherata e succo d'arancia",
            swapFood: "Porridge avena, whey isolate, semi di chia, anacardi e cioccolato 85%",
            originalKcal: 460,
            swapKcal: 410,
            originalSugars: 38,
            swapSugars: 6,
            originalProtein: 6,
            swapProtein: 25,
            metabolicBenefit: "-32g Zuccheri semplici, +19g Proteine nobili",
            whyItWorks: "Elimina il picco glicemico e il calo d'energia delle 11:00. I beta-glucani dell'avena e le mucillagini dei semi di chia formano un gel gastrico che garantisce 4-5 ore di sazietà piena."
        ),
        SmartSwap(
            category: "Colazione",
            originalFood: "Brioche da bar alla crema o cioccolato con cappuccino zuccherato",
            swapFood: "Pancake proteici d'avena con yogurt greco 0%, mirtilli e cannella",
            originalKcal: 520,
            swapKcal: 360,
            originalSugars: 36,
            swapSugars: 8,
            originalProtein: 7,
            swapProtein: 26,
            metabolicBenefit: "-160 kcal, -28g Zuccheri, zero grassi trans",
            whyItWorks: "Sostituisce i grassi idrogenati industriali con carboidrati complessi a lento rilascio e proteine ad altissimo valore biologico, preservando la sensibilità insulinica."
        ),
        SmartSwap(
            category: "Colazione",
            originalFood: "Biscotti frollini da colazione (6-8 pezzi) inzuppati nel latte intero",
            swapFood: "Porridge yogurt magro con 20g avena, 15g whey, 10g fondente e frutti di bosco",
            originalKcal: 480,
            swapKcal: 295,
            originalSugars: 32,
            swapSugars: 6,
            originalProtein: 8,
            swapProtein: 23,
            metabolicBenefit: "-185 kcal, -26g Zuccheri, +15g Proteine",
            whyItWorks: "I frollini industriali causano una rapida impennata di glucosio plasmatico. Lo yogurt greco combinato con avena prolunga la digestione mantenendo bassa l'insulina."
        ),
        SmartSwap(
            category: "Colazione",
            originalFood: "Pane bianco in cassetta tostato con burro e confettura tradizionale",
            swapFood: "Fetta di segale integrale con 15g burro d'arachidi 100% puro e fragole a fette",
            originalKcal: 380,
            swapKcal: 260,
            originalSugars: 28,
            swapSugars: 4,
            originalProtein: 5,
            swapProtein: 11,
            metabolicBenefit: "-24g Zuccheri, acidi grassi monoinsaturi e fibre",
            whyItWorks: "I grassi sani dell'arachide pura rallentano lo svuotamento gastrico e proteggono l'assetto lipidico favorendo un rilascio calorico costante."
        ),
        SmartSwap(
            category: "Colazione",
            originalFood: "Cereali estrusi glassati al miele/cioccolato con latte vaccino",
            swapFood: "Fiocchi d'avena integrali con latte di mandorla zero zuccheri e semi di lino",
            originalKcal: 420,
            swapKcal: 240,
            originalSugars: 34,
            swapSugars: 2,
            originalProtein: 7,
            swapProtein: 10,
            metabolicBenefit: "-180 kcal, -32g Zuccheri, ricca quota di Omega-3",
            whyItWorks: "I cereali soffiati hanno un indice glicemico paragonabile al glucosio puro. L'avena al naturale con latte di mandorla zero zuccheri azzera il carico glicemico."
        ),
        SmartSwap(
            category: "Colazione",
            originalFood: "Cappuccino da bar con bustina di zucchero bianco (5-7g)",
            swapFood: "Espresso o Americano con latte di mandorla zero zuccheri e cannella in polvere",
            originalKcal: 130,
            swapKcal: 35,
            originalSugars: 14,
            swapSugars: 0.5,
            originalProtein: 4,
            swapProtein: 2,
            metabolicBenefit: "-95 kcal, -13.5g Zuccheri a vuoto",
            whyItWorks: "La cannella possiede polifenoli che migliorano la sensibilità dei recettori cellulari all'insulina, trasformando il caffè in un alleato metabolico."
        ),
        
        // MARK: - 2. Pranzo / Cena (7 Sostituzioni)
        SmartSwap(
            category: "Pranzo / Cena",
            originalFood: "Pasta raffinata (120g) con sugo pronto all'amatriciana o panna",
            swapFood: "Anelletti o pasta integrale (90g) con macinato di manzo 5%, passata e 10g olio EVO",
            originalKcal: 680,
            swapKcal: 510,
            originalSugars: 11,
            swapSugars: 4,
            originalProtein: 18,
            swapProtein: 36,
            metabolicBenefit: "-170 kcal, +18g Proteine magre, -7g Zuccheri nascosti",
            whyItWorks: "I sughi pronti aggiungono zuccheri per correggere l'acidità. Il manzo magro al 5% fornisce ferro eme, creatina e un elevato effetto termico del cibo (TEF)."
        ),
        SmartSwap(
            category: "Pranzo / Cena",
            originalFood: "Cotoletta di pollo/maiale fritta panata con patatine fritte",
            swapFood: "Filetto di orata o spigola al vapore/forno con vellutata di zucca e 50g pane",
            originalKcal: 850,
            swapKcal: 535,
            originalSugars: 4,
            swapSugars: 7,
            originalProtein: 26,
            swapProtein: 48,
            metabolicBenefit: "-315 kcal, +22g Proteine, lipidi sani Omega-3",
            whyItWorks: "Elimina oltre 30g di oli vegetali ossidati dalla frittura. Il pesce bianco apporta proteine ad altissima digeribilità con zero affaticamento epatico serale."
        ),
        SmartSwap(
            category: "Pranzo / Cena",
            originalFood: "Pizza con salame piccante, salsiccia e formaggi fusi",
            swapFood: "Wrap o piadina integrale con 80g bresaola, pomodorini, rucola e fiocchi di latte magri",
            originalKcal: 1100,
            swapKcal: 460,
            originalSugars: 12,
            swapSugars: 3,
            originalProtein: 35,
            swapProtein: 42,
            metabolicBenefit: "-640 kcal, -25g Grassi saturi, +7g Proteine",
            whyItWorks: "Conserva il piacere di un pasto conviviale e gustoso senza l'eccesso calorico e di sodio tipico dei salumi lavorati da forno."
        ),
        SmartSwap(
            category: "Pranzo / Cena",
            originalFood: "Hamburger da fast food con cheddar fuso, bacon croccante e salse",
            swapFood: "Burger di scottona magra al piatto con 120g patate dolci al forno e verdure grigliate",
            originalKcal: 890,
            swapKcal: 480,
            originalSugars: 18,
            swapSugars: 6,
            originalProtein: 32,
            swapProtein: 44,
            metabolicBenefit: "-410 kcal, -12g Zuccheri delle salse, +12g Proteine",
            whyItWorks: "Le salse commerciali sono ricche di sciroppo di glucosio-fruttosio. Le patate dolci al forno offrono amido resistente e carotenoidi a basso impatto insulinico."
        ),
        SmartSwap(
            category: "Pranzo / Cena",
            originalFood: "Gnocchi di patate conditi con burro, salvia e formaggi stagionati",
            swapFood: "Gnocchi con 200g vellutata di zucca Delica, 80g ricotta magra e 5g olio EVO a crudo",
            originalKcal: 620,
            swapKcal: 420,
            originalSugars: 6,
            swapSugars: 6,
            originalProtein: 12,
            swapProtein: 22,
            metabolicBenefit: "-200 kcal, +10g Proteine, densità saziante tripla",
            whyItWorks: "La zucca espande il volume del piatto aumentando l'apporto di potassio e fibra solubile senza aggiungere calorie vuote."
        ),
        SmartSwap(
            category: "Pranzo / Cena",
            originalFood: "Sushi commerciale fritto (Crunch roll, maionese spicy e teriyaki)",
            swapFood: "Poke bowl con riso basmati, salmone crudo, edamame, cetriolo, alga nori e soia light",
            originalKcal: 790,
            swapKcal: 540,
            originalSugars: 22,
            swapSugars: 4,
            originalProtein: 20,
            swapProtein: 36,
            metabolicBenefit: "-250 kcal, -18g Zuccheri raffinati, +16g Proteine",
            whyItWorks: "La glassa teriyaki e le fritture da sushi contengono molto zucchero. Il riso basmati raffreddato sviluppa amido resistente benefico per il microbiota."
        ),
        SmartSwap(
            category: "Pranzo / Cena",
            originalFood: "Tagliere di formaggi stagionati grassi (pecorino, gorgonzola) a fine cena",
            swapFood: "Fiocchi di latte magri o Ricotta proteica con un pizzico di pepe nero e filo di EVO",
            originalKcal: 450,
            swapKcal: 160,
            originalSugars: 1,
            swapSugars: 2,
            originalProtein: 24,
            swapProtein: 26,
            metabolicBenefit: "-290 kcal, -24g Grassi saturi, proteine caseine lente",
            whyItWorks: "Le caseine micellari rilasciano aminoacidi gradualmente per tutta la notte, prevenendo il catabolismo notturno senza sovraccaricare la digestione."
        ),
        
        // MARK: - 3. Snack & Spuntini (6 Sostituzioni)
        SmartSwap(
            category: "Snack",
            originalFood: "Patatine fritte in busta o salatini industriali da aperitivo",
            swapFood: "Yogurt greco 0% con 10g anacardi o mandorle tostate non salate",
            originalKcal: 260,
            swapKcal: 145,
            originalSugars: 3,
            swapSugars: 4,
            originalProtein: 3,
            swapProtein: 15,
            metabolicBenefit: "+12g Proteine, -115 kcal, apporto di Magnesio e Zinco",
            whyItWorks: "Soddisfa il senso di appetito pomeridiano senza innescare sbalzi di sodio e lipidi raffinati che favoriscono la ritenzione idrica."
        ),
        SmartSwap(
            category: "Snack",
            originalFood: "Barretta di cioccolato al latte con wafer, nocciole e caramello",
            swapFood: "2 quadratini di cioccolato fondente 85% (15g) con 10g noci sgusciate",
            originalKcal: 270,
            swapKcal: 155,
            originalSugars: 26,
            swapSugars: 3,
            originalProtein: 3,
            swapProtein: 4,
            metabolicBenefit: "-23g Zuccheri rapidi, ricco carico di flavonoidi",
            whyItWorks: "Il cacao all'85% stimola la produzione di endorfine e placa la voglia di dolce grazie ai polifenoli che riducono lo stress ossidativo."
        ),
        SmartSwap(
            category: "Snack",
            originalFood: "Tramezzino da bar con maionese abbondante e tonno sott'olio",
            swapFood: "2 fette croccanti integrali tipo Wasa con 60g bresaola e fettine di lattuga",
            originalKcal: 380,
            swapKcal: 195,
            originalSugars: 4,
            swapSugars: 1,
            originalProtein: 11,
            swapProtein: 24,
            metabolicBenefit: "-185 kcal, -18g Grassi raffinati, +13g Proteine",
            whyItWorks: "Il pane morbido da tramezzino contiene alcol etilico e conservanti. La segale integrale croccante richiede masticazione prolungata aumentando la sazietà."
        ),
        SmartSwap(
            category: "Snack",
            originalFood: "Crackers salati industriali in pacchetto (35-40g)",
            swapFood: "2 gallette di riso integrale con 30g formaggio spalmabile proteico light",
            originalKcal: 190,
            swapKcal: 115,
            originalSugars: 2,
            swapSugars: 1.5,
            originalProtein: 3.5,
            swapProtein: 10,
            metabolicBenefit: "-75 kcal, triplo apporto proteico, meno sodio",
            whyItWorks: "I cracker commerciali hanno un carico glicemico rapido che genera appetito di rimbalzo entro 60 minuti."
        ),
        SmartSwap(
            category: "Snack",
            originalFood: "Gelato industriale confezionato su stecco con copertura croccante",
            swapFood: "Coppetta di yogurt greco 0% gelato con mirtilli congelati e aroma vaniglia",
            originalKcal: 320,
            swapKcal: 135,
            originalSugars: 29,
            swapSugars: 9,
            originalProtein: 3,
            swapProtein: 16,
            metabolicBenefit: "-185 kcal, -20g Zuccheri raffinati, +13g Proteine",
            whyItWorks: "Replica la freschezza e la vellutatezza del gelato eliminando lo sciroppo di glucosio e i grassi di palma a favore di proteine pure."
        ),
        SmartSwap(
            category: "Snack",
            originalFood: "Focaccia unta genovese o pizzetta da panificio a metà pomeriggio",
            swapFood: "1 mela verde a fette con un velo di cannella + 1 shake di proteine whey (20g)",
            originalKcal: 390,
            swapKcal: 180,
            originalSugars: 3,
            swapSugars: 14,
            originalProtein: 7,
            swapProtein: 22,
            metabolicBenefit: "-210 kcal, +15g Proteine, quota di pectina saziante",
            whyItWorks: "La pectina della mela unita alle proteine whey crea una distensione gastrica duratura che placa ogni stimolo di fame compulsiva serale."
        ),
        
        // MARK: - 4. Bevande (5 Sostituzioni)
        SmartSwap(
            category: "Bevande",
            originalFood: "Bibite gassate zuccherate (es. Spuma, Cola classica o Aranciata - lattina 330ml)",
            swapFood: "Acqua minerale frizzante con ghiaccio, fettina di limone fresco o Bevanda Zero",
            originalKcal: 140,
            swapKcal: 2,
            originalSugars: 35,
            swapSugars: 0,
            originalProtein: 0,
            swapProtein: 0,
            metabolicBenefit: "-35g Zuccheri liquidi immediati, -138 kcal",
            whyItWorks: "Gli zuccheri liquidi bypassano i recettori di sazietà e causano un picco insulinico acuto. Tagliarli preserva l'intero budget glucidico giornaliero (<40g)."
        ),
        SmartSwap(
            category: "Bevande",
            originalFood: "Tè freddo al limone o alla pesca in bottiglia (500ml)",
            swapFood: "Infuso di tè verde o rooibos freddo preparato in casa con menta e lime",
            originalKcal: 170,
            swapKcal: 4,
            originalSugars: 41,
            swapSugars: 0,
            originalProtein: 0,
            swapProtein: 0,
            metabolicBenefit: "-41g Zuccheri (superava l'intero target giornaliero!), zero calorie",
            whyItWorks: "Il tè industriale in bottiglia è fondamentalmente acqua e zucchero raffinato. Il tè verde fatto in casa apporta catechine (EGCG) che favoriscono l'ossidazione dei grassi."
        ),
        SmartSwap(
            category: "Bevande",
            originalFood: "Succhi di frutta confezionati '100% frutta' senza polpa",
            swapFood: "Spremuta fresca di 1 arancia allungata con acqua naturale o frizzante (Acqua & Agrumi)",
            originalKcal: 130,
            swapKcal: 50,
            originalSugars: 28,
            swapSugars: 9,
            originalProtein: 1,
            swapProtein: 1,
            metabolicBenefit: "-80 kcal, -19g Zuccheri, vitamina C viva intatta",
            whyItWorks: "I succhi pastorizzati rilasciano fruttosio ad assorbimento fulmineo che sovraccarica il fegato. La spremuta allungata idrata e apporta micronutrienti intatti."
        ),
        SmartSwap(
            category: "Bevande",
            originalFood: "Energy drink classico con zucchero (250ml)",
            swapFood: "Cold brew coffee o doppio espresso su cubetti di ghiaccio con scorzetta di limone",
            originalKcal: 115,
            swapKcal: 5,
            originalSugars: 27,
            swapSugars: 0,
            originalProtein: 0,
            swapProtein: 0.5,
            metabolicBenefit: "-27g Zuccheri raffinati, concentrazione mentale pura",
            whyItWorks: "La combinazione caffeina + saccarosio amplifica il cortisolo. Il caffè estratto a freddo offre caffeina pulita senza calorie né acidità gastrica."
        ),
        SmartSwap(
            category: "Bevande",
            originalFood: "Cocktail alcolico zuccherato (Spritz o drink con sciroppi dolci)",
            swapFood: "Mocktail tonica zero calorie con succo di mirtillo rosso puro, rosmarino e lime",
            originalKcal: 220,
            swapKcal: 25,
            originalSugars: 19,
            swapSugars: 3,
            originalProtein: 0,
            swapProtein: 0,
            metabolicBenefit: "-195 kcal, zero alcol (nessun blocco dell'ossidazione lipidica notturna)",
            whyItWorks: "L'alcol blocca temporaneamente la lipolisi perché il fegato prioritizza lo smaltimento dell'etanolo. Questo mocktail permette di godersi l'aperitivo a zero impatto."
        )
    ]
}
