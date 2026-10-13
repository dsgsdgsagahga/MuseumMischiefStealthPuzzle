import SwiftUI
import Combine
import UIKit

struct ShiftRecord: Codable {
    let duration: Double
    let peak: Double
    let stars: Int
}

final class MuseumStore: ObservableObject {
    @Published var unlocked: Int
    @Published var records: [Int: ShiftRecord]
    @Published var haptics: Bool { didSet { defaults.set(haptics, forKey: "haptics") } }
    @Published var reducedEffects: Bool { didSet { defaults.set(reducedEffects, forKey: "reducedEffects") } }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        unlocked = min(7, max(0, defaults.integer(forKey: "unlocked")))
        records = defaults.data(forKey: "records").flatMap { try? JSONDecoder().decode([Int: ShiftRecord].self, from: $0) } ?? [:]
        haptics = defaults.object(forKey: "haptics") as? Bool ?? true
        reducedEffects = defaults.bool(forKey: "reducedEffects")
    }

    func complete(_ level: Level, duration: Double, peak: Double) {
        let stars = 1 + (peak < 0.5 ? 1 : 0) + (duration <= level.targetTime ? 1 : 0)
        let record = ShiftRecord(duration: duration, peak: peak, stars: stars)
        if let old = records[level.id] {
            if stars > old.stars || (stars == old.stars && duration < old.duration) { records[level.id] = record }
        } else { records[level.id] = record }
        unlocked = max(unlocked, min(7, level.id + 1))
        defaults.set(unlocked, forKey: "unlocked")
        defaults.set(try? JSONEncoder().encode(records), forKey: "records")
    }
}

final class GameViewModel: ObservableObject {
    var engine: GameEngine
    let scene: GameScene
    let store: MuseumStore
    @Published var revision = 0
    @Published var choosingDecoy = false
    private var timer: AnyCancellable?
    private var lastTime: TimeInterval?
    private var warned = false

    init(level: Level, store: MuseumStore) {
        self.store = store
        engine = GameEngine(level: level)
        scene = GameScene(size: CGSize(width: 600, height: 800))
        scene.engine = engine
        scene.onTap = { [weak self] tile in self?.tap(tile) }
        scene.reducedEffects = store.reducedEffects
        scene.render()
    }

    func startClock() {
        guard timer == nil else { return }
        lastTime = nil
        timer = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect().sink { [weak self] date in
            guard let self else { return }
            let now = date.timeIntervalSinceReferenceDate
            let dt = self.lastTime.map { now - $0 } ?? 0
            self.lastTime = now
            let previous = self.engine.state
            self.engine.tick(dt)
            if self.engine.alarm > 0 && !self.warned && self.store.haptics {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
            self.warned = self.engine.alarm > 0
            if previous == .active && self.engine.state == .won {
                self.store.complete(self.engine.level, duration: self.engine.elapsed, peak: self.engine.peakAlarm)
            }
            self.scene.render()
            self.revision += 1
        }
    }

    func restart() {
        engine = GameEngine(level: engine.level)
        scene.engine = engine
        choosingDecoy = false
        warned = false
        lastTime = nil
        scene.render()
        revision += 1
    }

    func stopClock() { timer?.cancel(); timer = nil; lastTime = nil }
    func pause(_ value: Bool) { engine.paused = value; lastTime = nil; revision += 1 }
    func tap(_ tile: Tile) {
        if choosingDecoy { engine.distract(at: tile); choosingDecoy = false }
        else { engine.move(to: tile) }
        revision += 1
    }
    func interact() { engine.interact(); revision += 1 }
}
