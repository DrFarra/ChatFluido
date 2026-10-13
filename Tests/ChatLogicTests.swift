import XCTest

// Cada test es una regla de SPEC.md, observada en Watusi con REA.
final class ChatLogicTests: XCTestCase {
    private let on = MarkSettings(keepDeleted: true, keepEdited: true)

    private func stores() -> [MarkStore] { [SetMarkStore(), ListMarkStore()] }

    func testDeletedWinsOverEdited() {
        for s in stores() {
            s.addDeleted("A"); s.addEdited("A"); s.addEdited("B")
            XCTAssertEqual(mark(for: "A", settings: on, store: s), .deleted)
            XCTAssertEqual(mark(for: "B", settings: on, store: s), .edited)
            XCTAssertEqual(mark(for: "C", settings: on, store: s), .none)
        }
    }

    func testNoMarkWhenBothSettingsOff() {
        for s in stores() {
            s.addDeleted("A")
            XCTAssertEqual(mark(for: "A", settings: MarkSettings(keepDeleted: false, keepEdited: false), store: s), .none)
        }
    }

    func testEitherSettingEnablesBothMarks() {
        for s in stores() {
            s.addDeleted("A"); s.addEdited("B")
            let onlyDeleted = MarkSettings(keepDeleted: true, keepEdited: false)
            let onlyEdited = MarkSettings(keepDeleted: false, keepEdited: true)
            XCTAssertEqual(mark(for: "B", settings: onlyDeleted, store: s), .edited)
            XCTAssertEqual(mark(for: "A", settings: onlyEdited, store: s), .deleted)
        }
    }

    func testMissingOrEmptyIDHasNoMark() {
        for s in stores() {
            s.addDeleted("")
            XCTAssertEqual(mark(for: nil, settings: on, store: s), .none)
            XCTAssertEqual(mark(for: "", settings: on, store: s), .none)
        }
    }

    func testNewDeletionShowsFromThenOn() {
        for s in stores() {
            XCTAssertEqual(mark(for: "A", settings: on, store: s), .none)
            s.addDeleted("A")
            XCTAssertEqual(mark(for: "A", settings: on, store: s), .deleted)
        }
    }

    func testBothStoresAgreeOnDemoChat() {
        let set = SetMarkStore(), list = ListMarkStore()
        let chat = demoChat(count: 500, oldDeleted: 300, into: [set, list])
        for m in chat {
            XCTAssertEqual(mark(for: m.id, settings: on, store: set), mark(for: m.id, settings: on, store: list))
        }
        XCTAssertEqual(mark(for: chat[3].id, settings: on, store: set), .deleted)
        XCTAssertEqual(mark(for: chat[5].id, settings: on, store: set), .edited)
    }

    func testOpacityAndColorPerSide() {
        let red = RGBA(r: 1, g: 0, b: 0, a: 1), blue = RGBA(r: 0, g: 0, b: 1, a: 1)
        let theme = BubbleTheme(sentColor: red, receivedColor: blue, sentOpacity: 40, receivedOpacity: nil)
        XCTAssertEqual(bubbleStyle(isFromMe: true, theme: theme), BubbleStyle(color: red, alpha: 0.4))
        XCTAssertEqual(bubbleStyle(isFromMe: false, theme: theme), BubbleStyle(color: blue, alpha: 1))
        XCTAssertEqual(bubbleStyle(isFromMe: true, theme: BubbleTheme(sentOpacity: 0))?.alpha, 0)
        XCTAssertEqual(bubbleStyle(isFromMe: true, theme: BubbleTheme(sentOpacity: 100))?.alpha, 1)
    }

    func testThemeWithoutColorsLeavesBubbleUntouched() {
        XCTAssertNil(bubbleStyle(isFromMe: true, theme: BubbleTheme()))
    }

    func testSettingsAreCachedAndUpdated() {
        let d = UserDefaults(suiteName: "ChatLogicTests")!
        d.removePersistentDomain(forName: "ChatLogicTests")
        let s = Settings(defaults: d)
        XCTAssertEqual(s.marks, MarkSettings(keepDeleted: false, keepEdited: false))
        s.update(on)
        XCTAssertEqual(s.marks, on)
        XCTAssertEqual(Settings.read(d), on)
    }

    func testAboutBarTimings() {
        XCTAssertEqual(AboutBar.hideDuration, 0.3)
        XCTAssertEqual(AboutBar.showDelay, 0.7)
    }

    /// La razón de la versión propia: con muchos eliminados guardados, la lista es mucho más lenta.
    func testSetLookupIsMuchFasterThanList() {
        let set = SetMarkStore(), list = ListMarkStore()
        let chat = demoChat(count: 200, oldDeleted: 20_000, into: [set, list])
        func time(_ s: MarkStore) -> TimeInterval {
            let t0 = Date()
            for m in chat { _ = s.isDeleted(m.id); _ = s.isEdited(m.id) }
            return Date().timeIntervalSince(t0)
        }
        XCTAssertGreaterThan(time(list), time(set) * 10)
    }
}
