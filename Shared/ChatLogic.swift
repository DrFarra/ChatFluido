import Foundation

// Reglas de SPEC.md §3. Sin UIKit para poder probarlas sin pantalla.

enum Mark: Equatable { case none, deleted, edited }

enum Keys {
    static let keepDeleted = "keepDeletedMessages"
    static let keepEdited = "keepEditedMessages"
}

struct MarkSettings: Equatable {
    var keepDeleted: Bool
    var keepEdited: Bool
}

/// IDs de mensajes eliminados / editados.
protocol MarkStore: AnyObject {
    func isDeleted(_ id: String?) -> Bool
    func isEdited(_ id: String?) -> Bool
    func addDeleted(_ id: String)
    func addEdited(_ id: String)
}

/// Versión propia: conjuntos, búsqueda en tiempo constante.
final class SetMarkStore: MarkStore {
    private var deleted = Set<String>(), edited = Set<String>()
    func isDeleted(_ id: String?) -> Bool { id.map { deleted.contains($0) } ?? false }
    func isEdited(_ id: String?) -> Bool { id.map { edited.contains($0) } ?? false }
    func addDeleted(_ id: String) { deleted.insert(id) }
    func addEdited(_ id: String) { edited.insert(id) }
}

/// Como Watusi: NSMutableArray recorrido elemento a elemento (ev_86b032cf, ev_36d3dfbf).
final class ListMarkStore: MarkStore {
    private let deleted = NSMutableArray(), edited = NSMutableArray()
    func isDeleted(_ id: String?) -> Bool { id.map { deleted.contains($0) } ?? false }
    func isEdited(_ id: String?) -> Bool { id.map { edited.contains($0) } ?? false }
    func addDeleted(_ id: String) { deleted.add(id) }
    func addEdited(_ id: String) { edited.add(id) }
}

/// Si cualquiera de los dos ajustes está activo se miran las dos marcas; eliminado gana (ev_797d05d6).
func mark(for id: String?, settings: MarkSettings, store: MarkStore) -> Mark {
    guard settings.keepDeleted || settings.keepEdited, let id, !id.isEmpty else { return .none }
    if store.isDeleted(id) { return .deleted }
    return store.isEdited(id) ? .edited : .none
}

/// Ajustes leídos una vez; la app los cambia solo a través de `update`.
final class Settings {
    let defaults: UserDefaults
    private(set) var marks: MarkSettings

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        marks = Settings.read(defaults)
    }

    /// Lo que hace Watusi en cada llamada (ev_dd8ab32a).
    static func read(_ d: UserDefaults) -> MarkSettings {
        MarkSettings(keepDeleted: d.bool(forKey: Keys.keepDeleted), keepEdited: d.bool(forKey: Keys.keepEdited))
    }

    func update(_ m: MarkSettings) {
        defaults.set(m.keepDeleted, forKey: Keys.keepDeleted)
        defaults.set(m.keepEdited, forKey: Keys.keepEdited)
        marks = m
    }
}

struct RGBA: Equatable { var r, g, b, a: Double }

/// Opacidad en 0–100; nil = opacidad desactivada para ese lado.
struct BubbleTheme: Equatable {
    var sentColor: RGBA?, receivedColor: RGBA?
    var sentOpacity: Double?, receivedOpacity: Double?
}

struct BubbleStyle: Equatable {
    var color: RGBA?
    var alpha: Double
}

/// nil = el tema no toca las burbujas (ev_edff768b).
func bubbleStyle(isFromMe: Bool, theme: BubbleTheme) -> BubbleStyle? {
    let t = theme
    guard t.sentColor != nil || t.receivedColor != nil || t.sentOpacity != nil || t.receivedOpacity != nil else { return nil }
    let opacity = isFromMe ? t.sentOpacity : t.receivedOpacity
    return BubbleStyle(color: isFromMe ? t.sentColor : t.receivedColor,
                       alpha: opacity.map { min(max($0, 0), 100) / 100 } ?? 1)
}

/// Tiempos de la barra de info al arrastrar (ev_75b4b8a3, ev_fe434408).
enum AboutBar {
    static let hideDuration = 0.3
    static let showDelay = 0.7
}

struct Message {
    let id: String
    let text: String
    let isFromMe: Bool
}

/// Chat de prueba: uno de cada 7 eliminado, uno de cada 11 editado, más `oldDeleted` IDs
/// de otros chats, como la lista que Watusi acumula y nunca limpia (ev_d4034be0).
func demoChat(count: Int, oldDeleted: Int, into stores: [MarkStore]) -> [Message] {
    for i in 0..<oldDeleted { stores.forEach { $0.addDeleted(String(format: "OLD%016lX", i)) } }
    return (0..<count).map { i in
        let id = String(format: "3EB0%016lX", i)
        if i % 7 == 3 { stores.forEach { $0.addDeleted(id) } }
        if i % 11 == 5 { stores.forEach { $0.addEdited(id) } }
        return Message(id: id, text: "Mensaje \(i)" + String(repeating: " bla", count: i % 9),
                       isFromMe: i % 3 == 0)
    }
}
