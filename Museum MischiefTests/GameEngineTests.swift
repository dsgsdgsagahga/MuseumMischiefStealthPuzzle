import XCTest
@testable import Museum_Mischief

final class GameEngineTests: XCTestCase {
    private func custom(walls: Set<Tile> = [], routes: [[Tile]] = [], cameras: [Camera] = []) -> Level {
        Level(id: 0, title: "Test", subtitle: "Test", task: "Test", targetTime: 20, walls: walls, exhibits: [Exhibit(id: 0, name: "Vase", origin: Tile(x: 2, y: 2), destination: Tile(x: 2, y: 4), style: 0)], routes: routes, cameras: cameras)
    }
    private func advance(_ engine: GameEngine, seconds: Double) {
        for _ in 0..<Int(seconds * 100) { engine.tick(0.01) }
    }
    func testSightAndWalls() {
        let observer = Watcher(position: Position(x: 1.5, y: 2.5), angle: 0, range: 5, aperture: .pi / 2)
        let clear = GameEngine(level: custom())
        XCTAssertTrue(clear.visible(Position(x: 4.5, y: 2.5), to: observer))
        XCTAssertFalse(clear.visible(Position(x: 0.5, y: 2.5), to: observer))
        XCTAssertFalse(clear.visible(Position(x: 9, y: 2.5), to: observer))
        let blocked = GameEngine(level: custom(walls: [Tile(x: 3, y: 2)]))
        XCTAssertFalse(blocked.visible(Position(x: 4.5, y: 2.5), to: observer))
    }
    func testRouteAvoidsWalls() {
        let engine = GameEngine(level: custom(walls: [Tile(x: 2, y: 2)]))
        let route = engine.route(from: Tile(x: 1, y: 2), to: Tile(x: 3, y: 2))
        XCTAssertEqual(route.last, Tile(x: 3, y: 2))
        XCTAssertFalse(route.contains(Tile(x: 2, y: 2)))
        XCTAssertTrue(engine.route(from: Tile(x: 1, y: 2), to: Tile(x: 2, y: 2)).isEmpty)
    }
    func testAllLevelsHaveReachableAssignmentsAndValidPatrols() {
        XCTAssertEqual(Level.all.count, 8)
        for level in Level.all {
            let engine = GameEngine(level: level)
            for exhibit in level.exhibits {
                XCTAssertFalse(engine.route(from: level.exit, to: exhibit.origin).isEmpty, level.title)
                XCTAssertFalse(engine.route(from: exhibit.origin, to: exhibit.destination).isEmpty, level.title)
                XCTAssertFalse(engine.route(from: exhibit.destination, to: level.exit).isEmpty, level.title)
            }
            for route in level.routes {
                for index in route.indices {
                    let a = route[index].point
                    let b = route[(index + 1) % route.count].point
                    for step in 0...100 {
                        let fraction = Double(step) / 100
                        XCTAssertTrue(engine.isOpen(Position(x: a.x + (b.x - a.x) * fraction, y: a.y + (b.y - a.y) * fraction).tile), level.title)
                    }
                }
            }
        }
    }
    func testLiftPlaceExitAndReset() {
        let engine = GameEngine(level: custom())
        engine.player = Tile(x: 2, y: 2).point
        engine.interact()
        advance(engine, seconds: 0.5)
        XCTAssertNil(engine.carrying)
        advance(engine, seconds: 0.6)
        XCTAssertEqual(engine.carrying, 0)
        engine.player = Tile(x: 2, y: 4).point
        engine.interact()
        advance(engine, seconds: 1.1)
        XCTAssertTrue(engine.delivered.contains(0))
        XCTAssertEqual(engine.state, .active)
        engine.player = engine.level.exit.point
        engine.tick(0.01)
        XCTAssertEqual(engine.state, .won)
        let reset = GameEngine(level: engine.level)
        XCTAssertEqual(reset.elapsed, 0)
        XCTAssertTrue(reset.delivered.isEmpty)
        XCTAssertTrue(reset.decoyAvailable)
    }
    func testObservationBlocksInteractionAndTriggersAlarm() {
        let engine = GameEngine(level: custom(cameras: [Camera(tile: Tile(x: 1, y: 2), direction: 0, phase: 0)]))
        engine.player = Tile(x: 2, y: 2).point
        engine.interact()
        XCTAssertNil(engine.interaction)
        for _ in 0..<220 { engine.elapsed = 0; engine.tick(0.01) }
        XCTAssertEqual(engine.state, .lost)
        XCTAssertEqual(engine.peakAlarm, 1)
    }
    func testRecoveryPauseAndDecoy() {
        let engine = GameEngine(level: custom(routes: [[Tile(x: 8, y: 8), Tile(x: 8, y: 12)]]))
        engine.alarm = 0.6
        advance(engine, seconds: 1)
        XCTAssertEqual(engine.alarm, 0.35, accuracy: 0.01)
        let elapsed = engine.elapsed
        engine.paused = true
        advance(engine, seconds: 1)
        XCTAssertEqual(engine.elapsed, elapsed)
        engine.paused = false
        engine.distract(at: Tile(x: 9, y: 8))
        XCTAssertFalse(engine.decoyAvailable)
        XCTAssertEqual(engine.patrols[0].distraction, 4)
        advance(engine, seconds: 4.2)
        XCTAssertLessThanOrEqual(engine.patrols[0].distraction, 0)
    }
    func testInterruptedLiftAndSlowerCarrying() {
        let engine = GameEngine(level: custom(cameras: [Camera(tile: Tile(x: 8, y: 2), direction: .pi, phase: 0)]))
        engine.player = Tile(x: 2, y: 2).point
        engine.interact()
        XCTAssertNotNil(engine.interaction)
        engine.player = Tile(x: 7, y: 2).point
        engine.tick(0.01)
        XCTAssertNil(engine.interaction)
        XCTAssertNil(engine.carrying)
        let clear = GameEngine(level: custom())
        clear.player = Tile(x: 1, y: 1).point
        clear.move(to: Tile(x: 3, y: 1))
        advance(clear, seconds: 0.1)
        let normalDistance = clear.player.x - 1.5
        let loaded = GameEngine(level: custom())
        loaded.carrying = 0
        loaded.move(to: Tile(x: 3, y: 1))
        advance(loaded, seconds: 0.1)
        XCTAssertEqual(loaded.player.x - 1.5, normalDistance * 0.7, accuracy: 0.001)
    }
    func testDecoyLeavesCameraActive() {
        let engine = GameEngine(level: custom(routes: [[Tile(x: 8, y: 8), Tile(x: 8, y: 12)]], cameras: [Camera(tile: Tile(x: 1, y: 2), direction: 0, phase: 0)]))
        engine.distract(at: Tile(x: 9, y: 8))
        XCTAssertEqual(engine.watchers.count, 2)
        XCTAssertTrue(engine.observed(Tile(x: 2, y: 2).point))
        engine.distract(at: Tile(x: 4, y: 4))
        XCTAssertEqual(engine.patrols[0].distractionPoint, Tile(x: 9, y: 8).point)
    }
    func testProgressPersistsAndKeepsBestResult() {
        let suite = "MuseumTests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = MuseumStore(defaults: defaults)
        store.complete(Level.all[0], duration: 30, peak: 0.1)
        store.complete(Level.all[0], duration: 150, peak: 0.7)
        let restored = MuseumStore(defaults: defaults)
        XCTAssertEqual(restored.unlocked, 1)
        XCTAssertEqual(restored.records[0]?.stars, 3)
        XCTAssertEqual(restored.records[0]?.duration, 30)
    }
}
