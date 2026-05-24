import SwiftUI

@Observable
class AppTheme {
    struct ThemeColor: Identifiable {
        let id: String
        let name: String
        let color: Color
    }

    static let options: [ThemeColor] = [
        ThemeColor(id: "indigo",  name: "Indigo",  color: .indigo),
        ThemeColor(id: "blue",    name: "Blue",    color: .blue),
        ThemeColor(id: "purple",  name: "Purple",  color: .purple),
        ThemeColor(id: "teal",    name: "Teal",    color: .teal),
        ThemeColor(id: "orange",  name: "Orange",  color: .orange),
        ThemeColor(id: "pink",    name: "Pink",    color: .pink),
        ThemeColor(id: "coral",   name: "Coral",   color: Color("ThemeCoral")),
        ThemeColor(id: "forest",  name: "Forest",  color: Color("ThemeForest")),
    ]

    // Plain stored property — @Observable tracks this and triggers re-renders.
    // didSet persists the value to UserDefaults manually.
    var accentID: String = UserDefaults.standard.string(forKey: "accentColorID") ?? "indigo" {
        didSet {
            UserDefaults.standard.set(accentID, forKey: "accentColorID")
        }
    }

    var accent: Color {
        Self.options.first { $0.id == accentID }?.color ?? .indigo
    }
}
