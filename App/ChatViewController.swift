import UIKit

/// Las dos formas de hacer lo mismo: como Watusi (SPEC §5) o la versión propia (SPEC §6).
enum Mode: Int { case watusi, fixed }

struct ChatContext {
    let setStore: SetMarkStore
    let listStore: ListMarkStore
    let settings: Settings
    let theme: BubbleTheme
}

final class ChatViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    static let aboutTag = 0xbc962f // el número con el que Watusi busca su barra (ev_75b4b8a3)

    private let table = UITableView()
    private let aboutBar = UILabel()
    private let meterLabel = UILabel()
    private let meter = FrameMeter()
    private var mode = Mode.watusi
    private let ctx: ChatContext
    private let messages: [Message]

    init() {
        let set = SetMarkStore(), list = ListMarkStore()
        messages = demoChat(count: 3000, oldDeleted: 20_000, into: [set, list])
        let settings = Settings()
        settings.update(MarkSettings(keepDeleted: true, keepEdited: true))
        // Como tu tema: burbujas con transparencia.
        let theme = BubbleTheme(sentColor: RGBA(r: 0, g: 0.55, b: 0.45, a: 1),
                                receivedColor: RGBA(r: 0.25, g: 0.25, b: 0.3, a: 1),
                                sentOpacity: 55, receivedOpacity: 55)
        ctx = ChatContext(setStore: set, listStore: list, settings: settings, theme: theme)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no se usa") }

    override func viewDidLoad() {
        super.viewDidLoad()
        let wallpaper = GradientView()
        wallpaper.gradient.colors = [UIColor.systemIndigo.cgColor, UIColor.systemOrange.cgColor]
        table.backgroundView = wallpaper
        table.separatorStyle = .none
        table.dataSource = self
        table.delegate = self
        table.register(BubbleCell.self, forCellReuseIdentifier: "b")

        aboutBar.text = "Info: Disponible"
        aboutBar.textAlignment = .center
        aboutBar.backgroundColor = .secondarySystemBackground
        aboutBar.tag = Self.aboutTag

        [table, aboutBar].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; view.addSubview($0) }
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: view.topAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            aboutBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            aboutBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            aboutBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            aboutBar.heightAnchor.constraint(equalToConstant: 28),
        ])

        let modes = UISegmentedControl(items: ["Watusi", "Arreglado"])
        modes.selectedSegmentIndex = mode.rawValue
        modes.addAction(UIAction { [unowned self, unowned modes] _ in
            mode = Mode(rawValue: modes.selectedSegmentIndex) ?? .fixed
            table.reloadData()
        }, for: .valueChanged)
        navigationItem.titleView = modes

        meterLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        meterLabel.text = "Desliza el chat…"
        toolbarItems = [UIBarButtonItem(customView: meterLabel)]
        navigationController?.isToolbarHidden = false
        meter.onUpdate = { [weak self] text in
            self?.meterLabel.text = text
            self?.meterLabel.sizeToFit()
        }
        meter.start()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { messages.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "b", for: indexPath) as! BubbleCell
        cell.configure(messages[indexPath.row], ctx: ctx, mode: mode)
        return cell
    }

    // Watusi busca la barra por número en toda la pantalla en cada arrastre; aquí, referencia directa.
    private var bar: UIView? { mode == .watusi ? view.viewWithTag(Self.aboutTag) : aboutBar }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        UIView.animate(withDuration: AboutBar.hideDuration) { self.bar?.alpha = 0 }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + AboutBar.showDelay) {
            UIView.animate(withDuration: AboutBar.hideDuration) { self.bar?.alpha = 1 }
        }
    }
}

final class BubbleCell: UITableViewCell {
    static let markTag = 0x1f9ca // el número con el que Watusi busca su botón (ev_797d05d6)

    private let bubble = UIView()
    private let background = GradientView()
    private let label = UILabel()
    private let markView = UIImageView()
    private var left: NSLayoutConstraint!
    private var right: NSLayoutConstraint!
    private var message: Message?
    private var ctx: ChatContext?
    private var mode = Mode.fixed
    private var applied: BubbleStyle??

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        background.gradient.cornerRadius = 16
        label.numberOfLines = 0
        label.textColor = .white
        markView.tag = Self.markTag
        markView.tintColor = .white
        [bubble, background, label, markView].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        contentView.addSubview(bubble)
        bubble.addSubview(background)
        bubble.addSubview(label)
        contentView.addSubview(markView)
        left = bubble.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        right = bubble.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        NSLayoutConstraint.activate([
            bubble.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 3),
            bubble.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -3),
            bubble.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75),
            background.topAnchor.constraint(equalTo: bubble.topAnchor),
            background.bottomAnchor.constraint(equalTo: bubble.bottomAnchor),
            background.leadingAnchor.constraint(equalTo: bubble.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: bubble.trailingAnchor),
            label.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -12),
            markView.centerXAnchor.constraint(equalTo: bubble.leadingAnchor),
            markView.topAnchor.constraint(equalTo: bubble.topAnchor, constant: -4),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no se usa") }

    /// Versión propia: marca y estilo una vez por mensaje, y el estilo solo si cambió.
    func configure(_ m: Message, ctx: ChatContext, mode: Mode) {
        message = m
        self.ctx = ctx
        self.mode = mode
        label.text = m.text
        left.isActive = !m.isFromMe
        right.isActive = m.isFromMe
        guard mode == .fixed else { applied = nil; setNeedsLayout(); return }
        show(mark(for: m.id, settings: ctx.settings.marks, store: ctx.setStore), in: markView)
        let style = bubbleStyle(isFromMe: m.isFromMe, theme: ctx.theme)
        if applied != .some(style) { applied = style; apply(style) }
    }

    /// Como Watusi: todo de nuevo en cada layoutSubviews (0x16d8fc, 0x187b78, 0x18816c).
    override func layoutSubviews() {
        super.layoutSubviews()
        guard mode == .watusi, let m = message, let ctx else { return }
        let s = Settings.read(ctx.settings.defaults)
        var found = Mark.none
        if s.keepDeleted || s.keepEdited {
            let deleted = ctx.listStore.isDeleted(m.id), edited = ctx.listStore.isEdited(m.id)
            found = deleted ? .deleted : (edited ? .edited : .none)
        }
        show(found, in: contentView.viewWithTag(Self.markTag) as? UIImageView)
        apply(bubbleStyle(isFromMe: m.isFromMe, theme: ctx.theme))
    }

    private func show(_ mark: Mark, in view: UIImageView?) {
        view?.isHidden = mark == .none
        view?.image = UIImage(systemName: mark == .deleted ? "trash.circle.fill" : "pencil.circle.fill")
    }

    private func apply(_ style: BubbleStyle?) {
        let c = style?.color.map { UIColor(red: $0.r, green: $0.g, blue: $0.b, alpha: $0.a) } ?? .systemGray
        background.gradient.colors = [c.cgColor, c.withAlphaComponent(0.7).cgColor]
        background.gradient.opacity = Float(style?.alpha ?? 1)
    }
}

final class GradientView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
    var gradient: CAGradientLayer { layer as! CAGradientLayer }
}

/// Cuenta las imágenes que llegan tarde (más de 1,5 veces el tiempo de una imagen).
final class FrameMeter: NSObject {
    var onUpdate: ((String) -> Void)?
    private var link: CADisplayLink?
    private var last = 0.0, worst = 0.0, late = 0, frames = 0

    func start() {
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    @objc private func tick(_ link: CADisplayLink) {
        let budget = link.targetTimestamp - link.timestamp
        if last > 0 {
            let dt = link.timestamp - last
            worst = max(worst, dt)
            frames += 1
            if dt > budget * 1.5 { late += 1 }
        }
        last = link.timestamp
        guard frames >= 120 else { return }
        onUpdate?(String(format: "%.0f Hz · peor %.1f ms · %d tarde de %d", 1 / budget, worst * 1000, late, frames))
        worst = 0
        late = 0
        frames = 0
    }
}
