import SwiftUI
import SpriteKit

private let midnight = Color(red: 0.035, green: 0.065, blue: 0.11)
private let panel = Color(red: 0.075, green: 0.12, blue: 0.19)
private let brass = Color(red: 0.94, green: 0.76, blue: 0.43)
private let mint = Color(red: 0.32, green: 0.85, blue: 0.76)
private let primaryText = Color(red: 0.95, green: 0.96, blue: 0.98)
private let supportingText = Color(red: 0.72, green: 0.78, blue: 0.85)
private let warningText = Color(red: 1, green: 0.46, blue: 0.49)

struct MuseumRootView: View {
    @StateObject private var store = MuseumStore()
    var body: some View {
        NavigationStack {
            NightDeskView(store: store)
        }
        .foregroundStyle(primaryText)
        .tint(brass)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }
}

struct MuseumBackdrop: View {
    var body: some View {
        LinearGradient(colors: [panel, midnight, midnight], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
    }
}

struct PrimaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).frame(maxWidth: .infinity).frame(minHeight: 52)
            .foregroundStyle(midnight).background(brass.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 16))
    }
}

struct MuseumEmblem: View {
    var body: some View {
        ZStack {
            Circle().stroke(brass.opacity(0.16), lineWidth: 1).frame(width: 220, height: 220)
            Circle().stroke(brass.opacity(0.3), lineWidth: 1).frame(width: 178, height: 178)
            Image(systemName: "building.columns.fill").font(.system(size: 74, weight: .light)).foregroundStyle(brass)
            Image(systemName: "moon.stars.fill").font(.system(size: 28)).foregroundStyle(mint).offset(x: 80, y: -77)
            Text("EST. 1893").font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(4).foregroundStyle(brass).offset(y: 77)
        }.frame(height: 240).accessibilityHidden(true)
    }
}

struct NightDeskView: View {
    @ObservedObject var store: MuseumStore
    var body: some View {
        ZStack {
            MuseumBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack {
                        Label("NIGHT STAFF ONLY", systemImage: "moon.fill").font(.caption2.weight(.bold)).tracking(2).foregroundStyle(mint)
                        Spacer()
                        Text("23:47").font(.system(.caption, design: .monospaced)).foregroundStyle(supportingText)
                    }
                    MuseumEmblem().frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Museum\nMischief").font(.system(size: 48, weight: .bold, design: .serif)).foregroundStyle(brass)
                        Text("A little out of place.\nCompletely under the radar.").font(.title3).foregroundStyle(supportingText)
                    }
                    HStack(spacing: 20) {
                        stat("08", label: "GALLERIES")
                        stat(String(store.records.count), label: "SHIFTS CLEARED")
                        stat(String(store.records.values.reduce(0) { $0 + $1.stars }), label: "DISTINCTIONS")
                    }.padding(20).background(panel, in: RoundedRectangle(cornerRadius: 18))
                    NavigationLink { GalleriesView(store: store) } label: { Label("Begin your shift", systemImage: "arrow.right") }.buttonStyle(PrimaryStyle())
                    Text("The curator left a peculiar list. Rearrange the collection before anyone notices.").font(.subheadline).foregroundStyle(supportingText).lineSpacing(4)
                    HStack {
                        Image(systemName: "eye.slash").foregroundStyle(mint)
                        Text("Move quietly. Watch carefully.").font(.caption)
                    }
                }.padding(26).frame(maxWidth: 620).frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Night Desk")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink { PreferencesView(store: store) } label: { Label("Preferences", systemImage: "slider.horizontal.3") }
            }
        }
    }
    private func stat(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).font(.title2.weight(.semibold)).foregroundStyle(brass)
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(supportingText)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GalleriesView: View {
    @ObservedObject var store: MuseumStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selected = 0
    var body: some View {
        ZStack {
            MuseumBackdrop()
            if sizeClass == .regular {
                HStack(spacing: 0) {
                    list.frame(maxWidth: .infinity)
                    ScrollView { MissionContent(level: Level.all[selected])
                        NavigationLink("Enter gallery") { MissionBriefView(level: Level.all[selected], store: store) }.buttonStyle(PrimaryStyle()).padding()
                    }.frame(maxWidth: .infinity)
                }
            } else { list }
        }.navigationTitle("Galleries")
    }
    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("THE NIGHT COLLECTION").font(.caption.weight(.bold)).tracking(2).foregroundStyle(mint)
                Text("Eight rooms.\nOne unusual assignment.").font(.system(.title, design: .serif)).foregroundStyle(brass)
                ForEach(Level.all) { level in
                    if level.id <= store.unlocked {
                        if sizeClass == .regular {
                            Button { selected = level.id } label: { card(level) }.buttonStyle(.plain)
                        } else {
                            NavigationLink { MissionBriefView(level: level, store: store) } label: { card(level) }.buttonStyle(.plain)
                        }
                    } else { card(level) }
                }
            }.padding(22)
        }
    }
    private func card(_ level: Level) -> some View {
        HStack(spacing: 16) {
            Text(String(format: "%02d", level.id + 1)).font(.system(.title2, design: .serif)).foregroundStyle(brass).frame(width: 44, height: 54).background(brass.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 6) {
                Text(level.title).font(.headline).foregroundStyle(primaryText)
                Text(level.subtitle).font(.caption).foregroundStyle(supportingText).multilineTextAlignment(.leading)
                if let record = store.records[level.id] { Text(String(repeating: "★", count: record.stars)).foregroundStyle(brass).font(.caption) }
            }
            Spacer(minLength: 0)
            Image(systemName: level.id <= store.unlocked ? "chevron.right" : "lock.fill").foregroundStyle(mint)
        }.padding(16).frame(minHeight: 80).background(panel, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct MissionContent: View {
    let level: Level
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("ASSIGNMENT \(String(format: "%02d", level.id + 1))").font(.caption.weight(.bold)).tracking(2).foregroundStyle(mint)
            Text(level.title).font(.system(size: 34, weight: .bold, design: .serif)).foregroundStyle(brass)
            Text(level.subtitle).font(.title3).foregroundStyle(supportingText)
            Image(systemName: level.id == 0 ? "moon.stars" : "building.columns").font(.system(size: 64, weight: .ultraLight)).foregroundStyle(brass).frame(maxWidth: .infinity).padding(35).background(panel, in: RoundedRectangle(cornerRadius: 22)).accessibilityHidden(true)
            Text("THE CURATOR’S NOTE").font(.caption.weight(.bold)).tracking(2).foregroundStyle(mint)
            Text(level.task).font(.body).lineSpacing(5)
            HStack {
                Label("\(level.exhibits.count) exhibits", systemImage: "shippingbox")
                Spacer()
                Label("\(Int(level.targetTime))s target", systemImage: "clock")
            }.font(.caption).foregroundStyle(brass)
            Divider()
            instruction("hand.tap", "Choose your path", "Tap clear floor, an exhibit, or a glowing plinth to walk there.")
            instruction("eye.slash", "Wait for a clear moment", "Use Interact beside an exhibit. Lifting and placing each take one second.")
            instruction("waveform", "Create a diversion", "Use Decoy, then tap the floor. One nearby patrol looks away for four seconds.")
            instruction("door.left.hand.open", "Leave it wonderfully wrong", "Match each numbered plinth, then return to EXIT.")
        }.padding(24)
    }
    private func instruction(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).foregroundStyle(mint).frame(width: 26)
            VStack(alignment: .leading, spacing: 5) { Text(title).font(.subheadline.weight(.semibold)); Text(detail).font(.caption).foregroundStyle(supportingText) }
        }
    }
}

struct MissionBriefView: View {
    let level: Level
    @ObservedObject var store: MuseumStore
    var body: some View {
        ZStack { MuseumBackdrop()
            ScrollView {
                VStack {
                    MissionContent(level: level)
                    NavigationLink { NightShiftView(level: level, store: store) } label: { Label("Start the assignment", systemImage: "arrow.right") }.buttonStyle(PrimaryStyle()).padding(24)
                }.frame(maxWidth: 720).frame(maxWidth: .infinity)
            }
        }.navigationTitle("Mission Brief").navigationBarTitleDisplayMode(.inline)
    }
}

struct NightShiftView: View {
    @StateObject private var model: GameViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss
    @State private var exitConfirmation = false
    init(level: Level, store: MuseumStore) { _model = StateObject(wrappedValue: GameViewModel(level: level, store: store)) }
    var body: some View {
        ZStack {
            MuseumBackdrop()
            if model.engine.state != .active {
                ShiftReportView(model: model, retry: { model.restart() })
            } else {
                GeometryReader { geometry in
                    let wide = sizeClass == .regular || geometry.size.width > geometry.size.height
                    Group {
                        if wide {
                            HStack(spacing: 12) { field; ScrollView { hud }.frame(width: min(300, geometry.size.width * 0.35)) }
                        } else { VStack(spacing: 10) { compactStatus; field; hud } }
                    }.padding(12)
                }
                if model.engine.paused {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    VStack(spacing: 18) {
                        Image(systemName: "pause.circle").font(.system(size: 48)).foregroundStyle(brass)
                        Text("A quiet moment").font(.title2.weight(.bold))
                        Text("Your shift is on hold.").foregroundStyle(supportingText)
                        Button("Resume shift") { model.pause(false) }.buttonStyle(PrimaryStyle())
                        Button("Leave gallery", role: .destructive) { exitConfirmation = true }.frame(minHeight: 44)
                    }.padding(28).frame(maxWidth: 360).background(panel, in: RoundedRectangle(cornerRadius: 24)).padding()
                }
            }
        }
        .navigationTitle(model.engine.state == .active ? "Night Shift" : "Shift Report")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(model.engine.state == .active)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if model.engine.state == .active {
                    Button { model.pause(!model.engine.paused) } label: { Label(model.engine.paused ? "Resume" : "Pause", systemImage: model.engine.paused ? "play.fill" : "pause.fill") }
                }
            }
        }
        .confirmationDialog("Leave this assignment?", isPresented: $exitConfirmation, titleVisibility: .visible) {
            Button("Leave gallery", role: .destructive) { dismiss() }
            Button("Keep playing", role: .cancel) {}
        } message: { Text("This shift will restart next time.") }
        .onAppear { model.startClock() }
        .onDisappear { model.stopClock() }
        .onChange(of: scenePhase) { phase in if phase != .active { model.pause(true) } }
    }
    private var field: some View {
        SpriteView(scene: model.scene)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(brass.opacity(0.2)))
            .accessibilityLabel("Gallery floor. Tap to set a walking destination.")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    private var compactStatus: some View {
        HStack {
            Text(model.engine.level.title).font(.subheadline.weight(.semibold)).lineLimit(1)
            Spacer()
            Text(time).font(.system(.subheadline, design: .monospaced)).foregroundStyle(brass)
            Text("\(model.engine.delivered.count)/\(model.engine.level.exhibits.count)").font(.subheadline).foregroundStyle(mint)
        }.padding(.horizontal, 4)
    }
    private var time: String { String(format: "%02d:%02d", Int(model.engine.elapsed) / 60, Int(model.engine.elapsed) % 60) }
    private var hud: some View {
        VStack(alignment: .leading, spacing: 10) {
            if sizeClass == .regular { compactStatus }
            HStack {
                Label("Suspicion", systemImage: "eye").font(.caption)
                Spacer()
                Text("\(Int(model.engine.alarm * 100))%").font(.system(.caption, design: .monospaced)).foregroundStyle(model.engine.alarm > 0 ? warningText : mint)
            }
            ProgressView(value: model.engine.alarm).tint(model.engine.alarm > 0 ? warningText : mint)
            Text(model.choosingDecoy ? "Tap a clear tile to place your diversion." : model.engine.message).font(.caption).foregroundStyle(model.engine.alarm > 0 ? warningText : supportingText).frame(minHeight: 32, alignment: .topLeading)
            if let action = model.engine.interaction { ProgressView(action.placing ? "Placing exhibit…" : "Lifting exhibit…", value: action.elapsed).font(.caption).tint(brass) }
            HStack(spacing: 10) {
                Button { model.interact() } label: { Label(model.engine.carrying == nil ? "Interact" : "Place", systemImage: "hand.raised.fill") }.buttonStyle(PrimaryStyle()).disabled(model.engine.interaction != nil)
                Button { model.choosingDecoy.toggle() } label: {
                    VStack(spacing: 4) { Image(systemName: "waveform"); Text(model.choosingDecoy ? "Cancel" : "Decoy").font(.caption) }.frame(minWidth: 70, minHeight: 52)
                }.foregroundStyle(mint).background(panel, in: RoundedRectangle(cornerRadius: 14)).disabled(!model.engine.decoyAvailable || model.engine.patrols.isEmpty)
            }
            if sizeClass == .regular {
                Divider()
                Text("CURATOR’S CHECKLIST").font(.caption2.weight(.bold)).tracking(1).foregroundStyle(brass)
                ForEach(model.engine.level.exhibits) { exhibit in
                    Label(exhibit.name, systemImage: model.engine.delivered.contains(exhibit.id) ? "checkmark.circle.fill" : "circle").font(.subheadline).foregroundStyle(model.engine.delivered.contains(exhibit.id) ? mint : supportingText)
                }
            }
            if model.engine.level.id == 0 && model.engine.delivered.isEmpty {
                Text("01 · Tap the golden vase.\n02 · Lift it with Interact.\n03 · Walk to the glowing ring and Place.").font(.caption2).foregroundStyle(brass).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(14).background(panel.opacity(0.8), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct ShiftReportView: View {
    @ObservedObject var model: GameViewModel
    let retry: () -> Void
    private var won: Bool { model.engine.state == .won }
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: won ? "checkmark.seal" : "exclamationmark.shield").font(.system(size: 82, weight: .ultraLight)).foregroundStyle(won ? mint : warningText).padding(.top, 36)
                Text(won ? "Wonderfully misplaced." : "The museum is awake.").font(.system(size: 32, weight: .bold, design: .serif)).foregroundStyle(brass).multilineTextAlignment(.center)
                Text(won ? "The curator’s strange request is complete.\nYour secret is safe until morning." : "Someone noticed your midnight work.\nStudy their rhythm and try again.").foregroundStyle(supportingText).multilineTextAlignment(.center)
                VStack(spacing: 18) {
                    reportRow("Time on shift", "\(Int(model.engine.elapsed)) seconds")
                    reportRow("Peak suspicion", "\(Int(model.engine.peakAlarm * 100))%")
                    reportRow("Exhibits placed", "\(model.engine.delivered.count) / \(model.engine.level.exhibits.count)")
                }.padding(22).background(panel, in: RoundedRectangle(cornerRadius: 20))
                if won {
                    VStack(alignment: .leading, spacing: 12) {
                        award("Assignment complete", earned: true)
                        award("Suspicion below 50%", earned: model.engine.peakAlarm < 0.5)
                        award("Finished within \(Int(model.engine.level.targetTime)) seconds", earned: model.engine.elapsed <= model.engine.level.targetTime)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    if model.engine.level.id < 7 {
                        NavigationLink { MissionBriefView(level: Level.all[model.engine.level.id + 1], store: model.store) } label: { Label("Next assignment", systemImage: "arrow.right") }.buttonStyle(PrimaryStyle())
                    } else { Text("All eight galleries rearranged. A remarkable night.").foregroundStyle(mint) }
                }
                Button(won ? "Replay assignment" : "Try again") { retry() }.buttonStyle(PrimaryStyle())
            }.padding(26).frame(maxWidth: 600).frame(maxWidth: .infinity)
        }
    }
    private func reportRow(_ label: String, _ value: String) -> some View { HStack { Text(label).foregroundStyle(supportingText); Spacer(); Text(value).foregroundStyle(brass) }.font(.subheadline) }
    private func award(_ text: String, earned: Bool) -> some View { Label(text, systemImage: earned ? "star.fill" : "star").foregroundStyle(earned ? brass : supportingText).font(.subheadline) }
}

struct PreferencesView: View {
    @ObservedObject var store: MuseumStore
    var body: some View {
        Form {
            Section("Your night shift") {
                Toggle("Haptic warnings", isOn: $store.haptics)
                Toggle("Gentler visual effects", isOn: $store.reducedEffects)
            }
            Section("Field guide") {
                Label("Teal marks the exit and destination plinths.", systemImage: "circle.dashed").foregroundStyle(mint)
                Label("Red marks a watcher’s field of view.", systemImage: "eye").foregroundStyle(warningText)
                Label("Gold marks the museum’s exhibits.", systemImage: "building.columns").foregroundStyle(brass)
                Text("Carrying an exhibit slows your pace. Walls hide you from both patrols and lenses. A diversion affects one patrol, never a lens.")
            }
            Section("Museum Mischief") {
                Text("Eight quiet assignments. One extraordinary collection.")
                Text("Progress stays on this device.").foregroundStyle(supportingText)
            }
        }.scrollContentBackground(.hidden).background(MuseumBackdrop()).navigationTitle("Preferences").tint(mint)
    }
}
