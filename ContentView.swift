import SwiftUI
import AVFoundation
import UIKit

// MARK: - App entry (only one @main in the whole project)

@main
struct UnplugApp: App {
    var body: some Scene {
        WindowGroup {
            RootView().preferredColorScheme(.dark)
        }
    }
}

// MARK: - Theme

enum Theme {
    static let bgTop = Color(red: 0.03, green: 0.04, blue: 0.10)
    static let bgBottom = Color(red: 0.09, green: 0.04, blue: 0.20)
    static let accent = Color(red: 0.25, green: 0.85, blue: 0.75)
    static let accent2 = Color(red: 0.35, green: 0.55, blue: 1.0)
    static let danger = Color(red: 1.0, green: 0.35, blue: 0.40)
    static let dim = Color.white.opacity(0.6)
}

let flashColors: [Color] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink]

struct Backdrop: View {
    var body: some View {
        LinearGradient(colors: [Theme.bgTop, Theme.bgBottom],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

extension View {
    func card() -> some View {
        self.padding(18)
            .background(Color.white.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
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
    UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first?.screen
}

// MARK: - Data

struct LogEntry: Codable, Identifiable {
    enum Kind: String, Codable { case urge, goon }
    var id = UUID()
    var kind: Kind
    var date: Date
}

final class Store: ObservableObject {
    private let d = UserDefaults.standard

    @Published var startDate: Date {
        didSet { d.set(startDate.timeIntervalSince1970, forKey: "unplug.start") }
    }
    @Published var bestDays: Int {
        didSet { d.set(bestDays, forKey: "unplug.best") }
    }
    @Published var entries: [LogEntry] {
        didSet {
            if let data = try? JSONEncoder().encode(entries) {
                d.set(data, forKey: "unplug.entries")
            }
        }
    }

    init() {
        let t = d.double(forKey: "unplug.start")
        let start = t > 0 ? Date(timeIntervalSince1970: t) : Date()
        startDate = start
        bestDays = d.integer(forKey: "unplug.best")
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

    func currentDays(at date: Date = Date()) -> Int {
        max(0, Int(date.timeIntervalSince(startDate))) / 86400
    }

    func logUrge() {
        entries.insert(LogEntry(kind: .urge, date: Date()), at: 0)
    }

    func logGoon() {
        bestDays = max(bestDays, currentDays())
        entries.insert(LogEntry(kind: .goon, date: Date()), at: 0)
        startDate = Date()
    }

    func resetAll() {
        startDate = Date()
        bestDays = 0
        entries = []
    }
}

// MARK: - Root

struct RootView: View {
    @StateObject private var store = Store()

    var body: some View {
        TabView {
            TrackerView()
                .tabItem { Label("Tracker", systemImage: "flame.fill") }
            LightView()
                .tabItem { Label("Lights", systemImage: "bolt.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.fill") }
        }
        .tint(Theme.accent)
        .environmentObject(store)
    }
}

// MARK: - Tracker tab

struct TrackerView: View {
    @EnvironmentObject var store: Store
    @State private var showGoonConfirm = false
    @State private var toast: String?

    var body: some View {
        ZStack {
            Backdrop()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    Text("Unplug")
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TimelineView(.periodic(from: Date(), by: 20)) { ctx in
                        RingCard(now: ctx.date)
                    }

                    HStack(spacing: 12) {
                        StatBox(icon: "hand.raised.fill", title: "Urges beaten", value: store.urges, tint: Theme.accent)
                        StatBox(icon: "arrow.counterclockwise", title: "Goons", value: store.goons, tint: Theme.danger)
                        StatBox(icon: "trophy.fill", title: "Best streak",
                                value: max(store.bestDays, store.currentDays()), tint: .yellow)
                    }

                    MilestoneRow()

                    VStack(spacing: 12) {
                        Button {
                            store.logUrge()
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            showToast("Urge logged. You rode it out.")
                        } label: {
                            Label("Log Urge", systemImage: "hand.raised.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(
                                    LinearGradient(colors: [Theme.accent2, Theme.accent],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .foregroundColor(.black)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(PressStyle())

                        Button {
                            showGoonConfirm = true
                        } label: {
                            Label("Log Goon", systemImage: "arrow.counterclockwise")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(Theme.danger.opacity(0.9))
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(PressStyle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }

            if let t = toast {
                VStack {
                    Spacer()
                    Text(t)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.75))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.15)))
                        .padding(.bottom, 24)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .alert("Log a goon?", isPresented: $showGoonConfirm) {
            Button("Log it", role: .destructive) {
                store.logGoon()
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                showToast("Logged. Counter reset, keep going.")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This resets your day counter to 0. Your best streak is kept.")
        }
    }

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation { toast = nil }
        }
    }
}

struct RingCard: View {
    @EnvironmentObject var store: Store
    let now: Date

    private static let marks = [1, 3, 7, 14, 30, 60, 90, 180, 365]

    var body: some View {
        let secs = max(0, now.timeIntervalSince(store.startDate))
        let days = secs / 86400
        let prev = Double(Self.marks.last(where: { Double($0) <= days }) ?? 0)
        let next = Double(Self.marks.first(where: { Double($0) > days }) ?? ((Int(days / 365) + 1) * 365))
        let progress = min(1.0, max(0.0, (days - prev) / (next - prev)))
        let s = Int(secs)
        let wholeDays = s / 86400
        let hours = s % 86400 / 3600
        let mins = s % 3600 / 60

        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 18)
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(
                        LinearGradient(colors: [Theme.accent, Theme.accent2],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text("\(wholeDays)")
                        .font(.system(size: 84, weight: .bold, design: .rounded))
                        .minimumScaleFactor(0.5)
                    Text(wholeDays == 1 ? "day" : "days")
                        .font(.title3.weight(.medium))
                        .foregroundColor(Theme.dim)
                }
            }
            .frame(width: 250, height: 250)
            .padding(.top, 6)

            Text("since your last goon")
                .font(.subheadline)
                .foregroundColor(Theme.dim)

            Text("\(hours)h \(mins < 10 ? "0" : "")\(mins)m  •  next goal: \(Int(next)) days")
                .font(.footnote.weight(.medium))
                .foregroundColor(Theme.accent)
        }
        .frame(maxWidth: .infinity)
        .card()
    }
}

struct StatBox: View {
    let icon: String
    let title: String
    let value: Int
    let tint: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(tint)
            Text("\(value)")
                .font(.title2.bold())
            Text(title)
                .font(.caption)
                .foregroundColor(Theme.dim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.07))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct MilestoneRow: View {
    @EnvironmentObject var store: Store
    private let marks = [1, 7, 30, 90, 365]

    var body: some View {
        let best = max(store.bestDays, store.currentDays())
        VStack(alignment: .leading, spacing: 12) {
            Text("Milestones").font(.headline)
            HStack(spacing: 8) {
                ForEach(marks, id: \.self) { m in
                    let done = best >= m
                    VStack(spacing: 6) {
                        Image(systemName: done ? "checkmark.seal.fill" : "lock.fill")
                            .foregroundColor(done ? Theme.accent : Color.white.opacity(0.3))
                        Text("\(m)d")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(done ? Color.white : Theme.dim)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(done ? Theme.accent.opacity(0.18) : Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - Flashlight strobe

final class Torch: ObservableObject {
    @Published var running = false
    private var timer: Timer?
    private var isOn = false

    var available: Bool {
        AVCaptureDevice.default(for: .video)?.hasTorch ?? false
    }

    func start() {
        guard available, !running else { return }
        running = true
        UIApplication.shared.isIdleTimerDisabled = true
        flip()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.flip()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        isOn = false
        setTorch(false)
        running = false
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func flip() {
        isOn.toggle()
        setTorch(isOn)
    }

    private func setTorch(_ on: Bool) {
        guard let dev = AVCaptureDevice.default(for: .video), dev.hasTorch else { return }
        do {
            try dev.lockForConfiguration()
            dev.torchMode = on ? .on : .off
            dev.unlockForConfiguration()
        } catch {}
    }
}

// MARK: - Lights tab

struct LightView: View {
    @StateObject private var torch = Torch()
    @State private var colorMode = true
    @State private var showScreen = false
    @State private var showWarning = false
    @State private var pendingScreen = false

    var body: some View {
        ZStack {
            Backdrop()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    Text("Lights")
                        .font(.largeTitle.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)

                    strobeCard
                    therapyCard
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
        }
        .alert("Flashing lights", isPresented: $showWarning) {
            Button("Start") {
                if pendingScreen { showScreen = true } else { torch.start() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Don't use this if you have photosensitive epilepsy or are sensitive to flashing lights. Stop if you feel dizzy or unwell.")
        }
        .fullScreenCover(isPresented: $showScreen) {
            LightScreen(colorMode: colorMode)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            torch.stop()
        }
        .onDisappear { torch.stop() }
    }

    private var strobeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "flashlight.on.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)
                    .frame(width: 48, height: 48)
                    .background(Color.yellow.opacity(0.15))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Strobe light").font(.headline)
                    Text("Flashlight flashes every 0.5 seconds")
                        .font(.footnote)
                        .foregroundColor(Theme.dim)
                }
            }

            if !torch.available {
                Label("No flashlight on this device (iPads don't have one). Works on iPhone.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundColor(.orange)
            }

            Button {
                if torch.running {
                    torch.stop()
                } else {
                    pendingScreen = false
                    showWarning = true
                }
            } label: {
                Label(torch.running ? "Stop strobe" : "Start strobe",
                      systemImage: torch.running ? "stop.fill" : "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
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
            HStack(spacing: 12) {
                Image(systemName: "sun.max.fill")
                    .font(.title2)
                    .foregroundColor(Color.purple)
                    .frame(width: 48, height: 48)
                    .background(Color.purple.opacity(0.18))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Light therapy screen").font(.headline)
                    Text("Full screen flashes every 0.5 seconds")
                        .font(.footnote)
                        .foregroundColor(Theme.dim)
                }
            }

            Picker("Mode", selection: $colorMode) {
                Text("Color").tag(true)
                Text("Black & White").tag(false)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 0) {
                if colorMode {
                    ForEach(0..<flashColors.count, id: \.self) { i in
                        flashColors[i]
                    }
                } else {
                    Color.white
                    Color.black
                    Color.white
                    Color.black
                }
            }
            .frame(height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )

            Button {
                pendingScreen = true
                showWarning = true
            } label: {
                Label("Start light therapy", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PressStyle())

            Text("Tap the screen to stop.")
                .font(.footnote)
                .foregroundColor(Theme.dim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - Full-screen flashing

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
                Text("Tap anywhere to stop")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .padding(.bottom, 30)
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

// MARK: - History tab

struct HistoryView: View {
    @EnvironmentObject var store: Store
    @State private var showReset = false

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        ZStack {
            Backdrop()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("History")
                        .font(.largeTitle.bold())

                    if store.entries.isEmpty {
                        Text("Nothing logged yet. Your urges and goons will show up here.")
                            .font(.subheadline)
                            .foregroundColor(Theme.dim)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card()
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(store.entries) { e in
                                row(e)
                            }
                        }
                    }

                    Button {
                        showReset = true
                    } label: {
                        Text("Reset all data")
                            .font(.footnote.weight(.medium))
                            .foregroundColor(Theme.dim)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 16)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
        }
        .alert("Reset everything?", isPresented: $showReset) {
            Button("Reset", role: .destructive) { store.resetAll() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your counter, history and best streak will all be erased.")
        }
    }

    private func row(_ e: LogEntry) -> some View {
        let isUrge = e.kind == .urge
        return HStack(spacing: 12) {
            Image(systemName: isUrge ? "hand.raised.fill" : "arrow.counterclockwise")
                .foregroundColor(isUrge ? Theme.accent : Theme.danger)
                .frame(width: 40, height: 40)
                .background((isUrge ? Theme.accent : Theme.danger).opacity(0.15))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(isUrge ? "Urge beaten" : "Goon logged")
                    .font(.subheadline.weight(.semibold))
                Text(Self.fmt.string(from: e.date))
                    .font(.caption)
                    .foregroundColor(Theme.dim)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
