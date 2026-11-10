import SwiftUI
import AVFoundation
import UIKit

@main
struct UnplugApp: App {
    var body: some Scene {
        WindowGroup { RootView().preferredColorScheme(.dark) }
    }
}

// MARK: - Theme

enum Theme {
    static let bgTop = Color(red: 0.07, green: 0.03, blue: 0.15)
    static let bgBottom = Color(red: 0.17, green: 0.07, blue: 0.32)
    static let card = Color(red: 0.26, green: 0.15, blue: 0.45).opacity(0.55)
    static let accent = Color(red: 0.74, green: 0.52, blue: 1.0)
    static let pink = Color(red: 1.0, green: 0.45, blue: 0.80)
    static let danger = Color(red: 1.0, green: 0.38, blue: 0.45)
    static let dim = Color.white.opacity(0.6)
}

let flashColors: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink]

func plural(_ n: Int, _ w: String) -> String { "\(n) \(w)\(n == 1 ? "" : "s")" }

struct Backdrop: View {
    var body: some View {
        LinearGradient(colors: [Theme.bgTop, Theme.bgBottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

extension View {
    func card(_ pad: CGFloat = 18) -> some View {
        self.padding(pad)
            .background(Theme.card)
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

func activeScreen() -> UIScreen? {
    UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.screen
}

// MARK: - Data

struct LogEntry: Codable, Identifiable {
    enum Kind: String, Codable { case urge, goon }
    var id = UUID()
    var kind: Kind
    var date: Date
    var prevStart: Date? = nil
    var prevBest: Int? = nil
}

final class Store: ObservableObject {
    private let d = UserDefaults.standard

    @Published var startDate: Date { didSet { d.set(startDate.timeIntervalSince1970, forKey: "unplug.start") } }
    @Published var bestDays: Int { didSet { d.set(bestDays, forKey: "unplug.best") } }
    @Published var goalDays: Int { didSet { d.set(goalDays, forKey: "unplug.goal") } }
    @Published var entries: [LogEntry] {
        didSet { if let data = try? JSONEncoder().encode(entries) { d.set(data, forKey: "unplug.entries") } }
    }

    init() {
        let t = d.double(forKey: "unplug.start")
        let start = t > 0 ? Date(timeIntervalSince1970: t) : Date()
        startDate = start
        bestDays = d.integer(forKey: "unplug.best")
        let g = d.integer(forKey: "unplug.goal")
        goalDays = g > 0 ? g : 30
        if let data = d.data(forKey: "unplug.entries"),
           let decoded = try? JSONDecoder().decode([LogEntry].self, from: data) {
            entries = decoded
        } else {
            entries = []
        }
        if t == 0 { d.set(start.timeIntervalSince1970, forKey: "unplug.start") }
    }

    var urges: Int { entries.filter { $0.kind == .urge }.count }
    var goons: Int { entries.filter { $0.kind == .goon }.count }

    func elapsed(at date: Date = Date()) -> TimeInterval { max(0, date.timeIntervalSince(startDate)) }
    func currentDays(at date: Date = Date()) -> Int { Int(elapsed(at: date)) / 86400 }

    func logUrge() { entries.insert(LogEntry(kind: .urge, date: Date()), at: 0) }

    func logGoon() {
        let e = LogEntry(kind: .goon, date: Date(), prevStart: startDate, prevBest: bestDays)
        bestDays = max(bestDays, currentDays())
        entries.insert(e, at: 0)
        startDate = Date()
    }

    /// Deleting the most recent goon also restores the streak it reset.
    func delete(_ e: LogEntry) {
        if e.kind == .goon,
           let latest = entries.first(where: { $0.kind == .goon }), latest.id == e.id,
           let ps = e.prevStart {
            startDate = ps
            bestDays = e.prevBest ?? bestDays
        }
        entries.removeAll { $0.id == e.id }
    }

    func resetAll() {
        startDate = Date()
        bestDays = 0
        entries = []
    }
}

// MARK: - Root + tab bar

struct RootView: View {
    @StateObject private var store = Store()
    @State private var tab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Backdrop()
            Group {
                switch tab {
                case 0: HomeView()
                case 1: LightView()
                case 2: HistoryView()
                default: ProfileView()
                }
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            TabBar(selection: $tab)
        }
        .environmentObject(store)
    }
}

struct TabBar: View {
    @Binding var selection: Int
    private let items: [(String, String)] = [
        ("Home", "house.fill"), ("Light", "sun.max.fill"),
        ("History", "clock.fill"), ("Profile", "person.fill")
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<items.count, id: \.self) { i in
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selection = i }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: items[i].1).font(.system(size: 18, weight: .semibold))
                        Text(items[i].0).font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(selection == i ? Color.white : Theme.dim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selection == i ? Color.white.opacity(0.16) : Color.clear)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(Color(red: 0.12, green: 0.06, blue: 0.24).opacity(0.96))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.10)))
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: 560)
    }
}

struct ScreenHeader: View {
    let title: String
    var body: some View {
        Text(title).font(.largeTitle.bold()).frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Home

struct HomeView: View {
    @EnvironmentObject var store: Store
    @State private var showGoonConfirm = false
    @State private var showDateSheet = false
    @State private var toast: String?

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    HStack {
                        Text("Unplug").font(.largeTitle.bold())
                        Spacer()
                        TimelineView(.periodic(from: Date(), by: 30)) { ctx in
                            HStack(spacing: 6) {
                                Image(systemName: "flame.fill").foregroundColor(.orange)
                                Text("\(store.currentDays(at: ctx.date))").font(.headline)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }

                    WeekStrip()
                    timeCard

                    HStack(spacing: 12) {
                        actionCard(icon: "hand.raised.fill", title: "Log Urge", tint: Theme.accent) {
                            store.logUrge()
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            showToast("Urge logged. You rode it out.")
                        }
                        actionCard(icon: "arrow.counterclockwise", title: "Log Goon", tint: Theme.danger) {
                            showGoonConfirm = true
                        }
                        GoalCard()
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }

            if let t = toast {
                VStack {
                    Spacer()
                    Text(t)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Capsule())
                        .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showDateSheet) { StartDateSheet().environmentObject(store) }
        .alert("Log a goon?", isPresented: $showGoonConfirm) {
            Button("Log it", role: .destructive) {
                store.logGoon()
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                showToast("Logged. Counter reset, keep going.")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This resets your counter to 0. You can undo it later from History.")
        }
    }

    private var timeCard: some View {
        Button { showDateSheet = true } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Time since last goon")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Theme.dim)
                TimelineView(.periodic(from: Date(), by: 1)) { ctx in
                    let s = Int(store.elapsed(at: ctx.date))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(plural(s / 86400, "day")), \(plural(s % 86400 / 3600, "hour"))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.6)
                        Text("\(s % 3600 / 60) min, \(s % 60) sec")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.accent)
                    }
                }
                Label("Tap to change your start date", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(Theme.dim)
                    .padding(.top, 4)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
        .buttonStyle(PressStyle())
    }

    private func actionCard(icon: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(tint)
                    .frame(width: 52, height: 52)
                    .background(tint.opacity(0.18))
                    .clipShape(Circle())
                Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, minHeight: 130)
            .card(10)
        }
        .buttonStyle(PressStyle())
    }

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { withAnimation { toast = nil } }
    }
}

struct GoalCard: View {
    @EnvironmentObject var store: Store

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 30)) { ctx in
            let days = store.elapsed(at: ctx.date) / 86400
            let p = min(1.0, days / Double(max(1, store.goalDays)))
            VStack(spacing: 10) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 9)
                    Circle().trim(from: 0, to: CGFloat(p))
                        .stroke(LinearGradient(colors: [Theme.accent, Theme.pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(p * 100))%").font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .frame(width: 62, height: 62)
                Text("of your goal").font(.caption.weight(.medium)).foregroundColor(Theme.dim)
            }
            .frame(maxWidth: .infinity, minHeight: 130)
            .card(10)
        }
    }
}

struct WeekStrip: View {
    @EnvironmentObject var store: Store

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekStart = cal.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let startDay = cal.startOfDay(for: store.startDate)

        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { i in
                let day = cal.date(byAdding: .day, value: i, to: weekStart) ?? today
                let isToday = cal.isDate(day, inSameDayAs: today)
                let future = day > today
                let goon = store.entries.contains { $0.kind == .goon && cal.isDate($0.date, inSameDayAs: day) }
                let clean = !future && !goon && day >= startDay
                let sym = cal.shortWeekdaySymbols[cal.component(.weekday, from: day) - 1]

                VStack(spacing: 6) {
                    Text(sym).font(.caption2.weight(.semibold))
                        .foregroundColor(isToday ? Color.black.opacity(0.6) : Theme.dim)
                    ZStack {
                        if goon {
                            Circle().fill(Theme.danger.opacity(0.9))
                        } else if clean {
                            Circle().fill(Theme.accent.opacity(isToday ? 1 : 0.85))
                        } else {
                            Circle().stroke(Color.white.opacity(future ? 0.12 : 0.35),
                                            style: StrokeStyle(lineWidth: 1.5, dash: future ? [] : [3, 3]))
                        }
                        Text("\(cal.component(.day, from: day))")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(goon || clean ? Color.black.opacity(0.8)
                                             : (future ? Color.white.opacity(0.3) : Theme.dim))
                    }
                    .frame(width: 34, height: 34)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(isToday ? Color.white : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}

struct StartDateSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()

    var body: some View {
        ZStack {
            Backdrop()
            ScrollView {
                VStack(spacing: 16) {
                    Text("When did you stop?").font(.title2.bold()).padding(.top, 24)
                    Text("Pick the day and time of your last goon.")
                        .font(.subheadline).foregroundColor(Theme.dim)
                    DatePicker("", selection: $date, in: ...Date(),
                               displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .tint(Theme.accent)
                        .card(10)
                    Button {
                        store.startDate = date
                        dismiss()
                    } label: {
                        Text("Save").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(Theme.accent).foregroundColor(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(PressStyle())
                    Button("Cancel") { dismiss() }.foregroundColor(Theme.dim)
                }
                .padding(.horizontal)
                .frame(maxWidth: 560)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { date = store.startDate }
    }
}

// MARK: - Torch

final class Torch: ObservableObject {
    @Published var running = false
    private var timer: Timer?
    private var isOn = false

    var available: Bool { AVCaptureDevice.default(for: .video)?.hasTorch ?? false }

    func start() {
        guard available, !running else { return }
        running = true
        UIApplication.shared.isIdleTimerDisabled = true
        flip()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.flip() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isOn = false
        setTorch(false)
        running = false
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func flip() { isOn.toggle(); setTorch(isOn) }

    private func setTorch(_ on: Bool) {
        guard let dev = AVCaptureDevice.default(for: .video), dev.hasTorch else { return }
        do {
            try dev.lockForConfiguration()
            dev.torchMode = on ? .on : .off
            dev.unlockForConfiguration()
        } catch {}
    }
}

// MARK: - Lights

struct LightView: View {
    @StateObject private var torch = Torch()
    @State private var colorMode = true
    @State private var showScreen = false
    @State private var showWarning = false
    @State private var pendingScreen = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                ScreenHeader(title: "Light")
                strobeCard
                therapyCard
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .alert("Flashing lights", isPresented: $showWarning) {
            Button("Start") { if pendingScreen { showScreen = true } else { torch.start() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Don't use this if you have photosensitive epilepsy or are sensitive to flashing lights. Stop if you feel dizzy or unwell.")
        }
        .fullScreenCover(isPresented: $showScreen) { LightScreen(colorMode: colorMode) }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            torch.stop()
        }
        .onDisappear { torch.stop() }
    }

    private func header(_ icon: String, _ tint: Color, _ title: String, _ sub: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).foregroundColor(tint)
                .frame(width: 48, height: 48).background(tint.opacity(0.18)).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(sub).font(.footnote).foregroundColor(Theme.dim)
            }
        }
    }

    private var strobeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            header("flashlight.on.fill", .yellow, "Strobe light", "Flashlight flashes every 0.5 seconds")
            if !torch.available {
                Label("No flashlight on this device (iPads don't have one). Works on iPhone.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote).foregroundColor(.orange)
            }
            Button {
                if torch.running { torch.stop() } else { pendingScreen = false; showWarning = true }
            } label: {
                Label(torch.running ? "Stop strobe" : "Start strobe",
                      systemImage: torch.running ? "stop.fill" : "play.fill")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(torch.running ? Theme.danger : Color.yellow)
                    .foregroundColor(torch.running ? .white : .black)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PressStyle())
            .disabled(!torch.available)
            .opacity(torch.available ? 1 : 0.4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var therapyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            header("sun.max.fill", Theme.accent, "Light therapy screen", "Full screen flashes every 0.5 seconds")
            Picker("Mode", selection: $colorMode) {
                Text("Color").tag(true)
                Text("Black & White").tag(false)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 0) {
                if colorMode {
                    ForEach(0..<flashColors.count, id: \.self) { i in flashColors[i] }
                } else {
                    Color.white; Color.black; Color.white; Color.black
                }
            }
            .frame(height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button {
                pendingScreen = true
                showWarning = true
            } label: {
                Label("Start light therapy", systemImage: "play.fill")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(Theme.accent).foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PressStyle())

            Text("Tap the screen to stop.").font(.footnote).foregroundColor(Theme.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct LightScreen: View {
    let colorMode: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var phase = 0
    @State private var savedBrightness: CGFloat = 0.5
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var current: Color {
        if colorMode { return flashColors[phase % flashColors.count] }
        return phase % 2 == 0 ? Color.white : Color.black
    }

    var body: some View {
        ZStack {
            current.ignoresSafeArea()
            VStack {
                Spacer()
                Text("Tap anywhere to stop").font(.footnote).foregroundColor(.gray).padding(.bottom, 30)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { dismiss() }
        .onReceive(timer) { _ in phase += 1 }
        .onAppear {
            if let screen = activeScreen() {
                savedBrightness = screen.brightness
                screen.brightness = 1.0
            }
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            activeScreen()?.brightness = savedBrightness
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .statusBar(hidden: true)
    }
}

// MARK: - History (with delete)

struct HistoryView: View {
    @EnvironmentObject var store: Store
    @State private var toDelete: LogEntry?

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private var deleteMessage: String {
        guard let e = toDelete else { return "" }
        let isLatestGoon = e.kind == .goon && store.entries.first(where: { $0.kind == .goon })?.id == e.id
        return isLatestGoon ? "This also restores the streak it reset." : "This removes it from your history."
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                ScreenHeader(title: "History")
                if store.entries.isEmpty {
                    Text("Nothing logged yet. Urges and goons you log show up here, and you can delete any by mistake.")
                        .font(.subheadline).foregroundColor(Theme.dim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(store.entries) { e in row(e) }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .alert("Delete entry?", isPresented: Binding(get: { toDelete != nil },
                                                    set: { if !$0 { toDelete = nil } })) {
            Button("Delete", role: .destructive) {
                if let e = toDelete { store.delete(e) }
                toDelete = nil
            }
            Button("Cancel", role: .cancel) { toDelete = nil }
        } message: {
            Text(deleteMessage)
        }
    }

    private func row(_ e: LogEntry) -> some View {
        let isUrge = e.kind == .urge
        let tint = isUrge ? Theme.accent : Theme.danger
        return HStack(spacing: 12) {
            Image(systemName: isUrge ? "hand.raised.fill" : "arrow.counterclockwise")
                .foregroundColor(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.18))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(isUrge ? "Urge beaten" : "Goon logged").font(.subheadline.weight(.semibold))
                Text(Self.fmt.string(from: e.date)).font(.caption).foregroundColor(Theme.dim)
            }
            Spacer()
            Button {
                toDelete = e
            } label: {
                Image(systemName: "trash.fill")
                    .foregroundColor(Theme.dim)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(PressStyle())
        }
        .padding(12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Profile

struct ProfileView: View {
    @EnvironmentObject var store: Store
    @State private var showDateSheet = false
    @State private var showReset = false

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                ScreenHeader(title: "Profile")

                Button { showDateSheet = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("I stopped on").font(.footnote).foregroundColor(Theme.dim)
                            Text(Self.fmt.string(from: store.startDate)).font(.headline)
                        }
                        Spacer()
                        Image(systemName: "calendar").foregroundColor(Theme.accent)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }
                .buttonStyle(PressStyle())

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Goal").font(.footnote).foregroundColor(Theme.dim)
                        Text("Days to reach").font(.headline)
                    }
                    Spacer()
                    Picker("Goal", selection: $store.goalDays) {
                        ForEach([7, 14, 30, 60, 90, 180, 365], id: \.self) { Text("\($0) days").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.accent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                HStack(spacing: 12) {
                    stat("Urges beaten", store.urges)
                    stat("Goons", store.goons)
                    stat("Best streak", max(store.bestDays, store.currentDays()))
                }

                Button { showReset = true } label: {
                    Text("Reset all data").font(.footnote.weight(.medium)).foregroundColor(Theme.danger)
                        .frame(maxWidth: .infinity).padding(.top, 12)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .sheet(isPresented: $showDateSheet) { StartDateSheet().environmentObject(store) }
        .alert("Reset everything?", isPresented: $showReset) {
            Button("Reset", role: .destructive) { store.resetAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your counter, history and best streak will all be erased.")
        }
    }

    private func stat(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 4) {
            Text("\(value)").font(.title2.bold())
            Text(title).font(.caption).foregroundColor(Theme.dim).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card(12)
    }
}
