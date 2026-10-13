import Foundation

struct Tile: Hashable, Codable {
    var x: Int
    var y: Int
    var point: Position { Position(x: Double(x) + 0.5, y: Double(y) + 0.5) }
}

struct Position: Equatable {
    var x: Double
    var y: Double
    var tile: Tile { Tile(x: Int(x), y: Int(y)) }
    func distance(to other: Position) -> Double { hypot(x - other.x, y - other.y) }
}

struct Exhibit: Identifiable {
    let id: Int
    let name: String
    let origin: Tile
    let destination: Tile
    let style: Int
}

struct Watcher {
    var position: Position
    var angle: Double
    var range: Double
    var aperture: Double
}

struct Patrol {
    let route: [Tile]
    var position: Position
    var next = 1
    var angle = 0.0
    var wait = 0.0
    var distraction = 0.0
    var distractionPoint: Position?
}

struct Camera {
    let tile: Tile
    let direction: Double
    let phase: Double
}

struct Level: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let task: String
    let targetTime: Double
    let walls: Set<Tile>
    let exhibits: [Exhibit]
    let routes: [[Tile]]
    let cameras: [Camera]
    let exit = Tile(x: 1, y: 1)
    let width = 12
    let height = 16

    static let all: [Level] = {
        let titles = ["The Quiet Wing", "After Hours", "Watching Eyes", "Behind the Marble", "A Small Diversion", "Odd Company", "Crossed Gazes", "The Grand Rearrangement"]
        let hints = ["Learn the art of a quiet rearrangement.", "Study a predictable patrol before you move.", "Wait for the lens to look away.", "Use the partitions to break sight lines.", "A distant sound can buy a little time.", "Three treasures. One pair of hands.", "Patrols and lenses share the same room.", "Leave the collection wonderfully out of place."]
        return (0..<8).map { index in
            var walls = Set<Tile>()
            for x in 0..<12 { walls.insert(Tile(x: x, y: 0)); walls.insert(Tile(x: x, y: 15)) }
            for y in 0..<16 { walls.insert(Tile(x: 0, y: y)); walls.insert(Tile(x: 11, y: y)) }
            walls.insert(Tile(x: 4 + index % 3, y: 2 + index))
            if index >= 3 {
                for y in 5...10 { walls.insert(Tile(x: index % 2 == 0 ? 5 : 6, y: y)) }
            }
            if index >= 5 { walls.insert(Tile(x: 3, y: 8)) }
            let count = index >= 5 ? 3 : (index >= 3 ? 2 : 1)
            let names = ["Moon Vase", "Bronze Owl", "Royal Bust"]
            let exhibits = (0..<count).map { n in Exhibit(id: n, name: names[n], origin: Tile(x: 2 + n * 3, y: 3), destination: Tile(x: 2 + n * 3, y: 12 + index % 2), style: n) }
            var routes: [[Tile]] = []
            if index == 1 || index >= 3 { routes.append([Tile(x: 9, y: 5), Tile(x: 9, y: 12), Tile(x: 7, y: 12), Tile(x: 7, y: 5)]) }
            if index == 7 { routes.append([Tile(x: 2, y: 7), Tile(x: 4, y: 7), Tile(x: 4, y: 11), Tile(x: 2, y: 11)]) }
            let cameras = index == 2 || index >= 6 ? [Camera(tile: Tile(x: 9, y: 14), direction: -.pi / 2, phase: Double(index))] : []
            return Level(id: index, title: titles[index], subtitle: hints[index], task: "Move " + exhibits.map(\.name).joined(separator: ", ") + " to the glowing plinths, then return to the exit.", targetTime: Double(90 + count * 35 + index * 10), walls: walls, exhibits: exhibits, routes: routes, cameras: cameras)
        }
    }()
}

enum ShiftState { case active, won, lost }

final class GameEngine {
    let level: Level
    var player: Position
    var path: [Tile] = []
    var patrols: [Patrol]
    var positions: [Int: Tile]
    var delivered = Set<Int>()
    var carrying: Int?
    var elapsed = 0.0
    var alarm = 0.0
    var peakAlarm = 0.0
    var state = ShiftState.active
    var paused = false
    var decoyAvailable = true
    var interaction: (id: Int, placing: Bool, elapsed: Double)?
    var message = "Tap the floor to move. Stay outside the red light."

    init(level: Level) {
        self.level = level
        player = level.exit.point
        positions = Dictionary(uniqueKeysWithValues: level.exhibits.map { ($0.id, $0.origin) })
        patrols = level.routes.map { Patrol(route: $0, position: $0[0].point) }
    }

    func route(from start: Tile, to end: Tile) -> [Tile] {
        guard isOpen(end), isOpen(start) else { return [] }
        var queue = [start]
        var visited: Set<Tile> = [start]
        var previous: [Tile: Tile] = [:]
        var cursor = 0
        while cursor < queue.count {
            let tile = queue[cursor]
            cursor += 1
            if tile == end {
                var result: [Tile] = []
                var current = end
                while current != start {
                    result.append(current)
                    guard let parent = previous[current] else { return [] }
                    current = parent
                }
                return result.reversed()
            }
            for next in [Tile(x: tile.x + 1, y: tile.y), Tile(x: tile.x - 1, y: tile.y), Tile(x: tile.x, y: tile.y + 1), Tile(x: tile.x, y: tile.y - 1)] where isOpen(next) && !visited.contains(next) {
                visited.insert(next)
                previous[next] = tile
                queue.append(next)
            }
        }
        return []
    }

    func isOpen(_ tile: Tile) -> Bool {
        tile.x >= 0 && tile.x < level.width && tile.y >= 0 && tile.y < level.height && !level.walls.contains(tile)
    }

    func move(to tile: Tile) {
        guard state == .active, !paused, interaction == nil else { return }
        guard isOpen(tile) else { message = "Choose a clear patch of floor."; return }
        path = route(from: player.tile, to: tile)
        if player.distance(to: player.tile.point) > 0.01 { path.insert(player.tile, at: 0) }
        message = "Keep an eye on the patrols."
    }

    var watchers: [Watcher] {
        patrols.map { Watcher(position: $0.position, angle: $0.angle, range: 3.8, aperture: .pi / 3) } + level.cameras.map {
            Watcher(position: $0.tile.point, angle: $0.direction + sin(elapsed * 0.65 + $0.phase) * 1.1, range: 5.5, aperture: .pi / 4)
        }
    }

    func visible(_ point: Position, to watcher: Watcher) -> Bool {
        let distance = point.distance(to: watcher.position)
        guard distance <= watcher.range else { return false }
        let bearing = atan2(point.y - watcher.position.y, point.x - watcher.position.x)
        let delta = atan2(sin(bearing - watcher.angle), cos(bearing - watcher.angle))
        guard abs(delta) <= watcher.aperture / 2 || distance < 0.35 else { return false }
        let steps = max(1, Int(distance * 20))
        for step in 1...steps {
            let fraction = Double(step) / Double(steps)
            let sample = Position(x: watcher.position.x + (point.x - watcher.position.x) * fraction, y: watcher.position.y + (point.y - watcher.position.y) * fraction)
            if level.walls.contains(sample.tile) { return false }
        }
        return true
    }

    func observed(_ point: Position) -> Bool { watchers.contains { visible(point, to: $0) } }

    func interact() {
        guard state == .active, !paused, interaction == nil else { return }
        path = []
        if let id = carrying, let exhibit = level.exhibits.first(where: { $0.id == id }) {
            guard player.distance(to: exhibit.destination.point) < 0.9 else { message = "Carry it to its matching glowing plinth."; return }
            guard !observed(player), !observed(exhibit.destination.point) else { message = "Wait until the light passes."; return }
            interaction = (id, true, 0)
        } else if let exhibit = level.exhibits.first(where: { !delivered.contains($0.id) && player.distance(to: positions[$0.id]!.point) < 0.9 }) {
            guard !observed(player), !observed(positions[exhibit.id]!.point) else { message = "This exhibit is being watched."; return }
            interaction = (exhibit.id, false, 0)
        } else { message = "Stand beside an exhibit to lift it." }
    }

    func distract(at tile: Tile) {
        guard decoyAvailable, !paused, state == .active, isOpen(tile), !patrols.isEmpty else { message = "No patrol can hear a diversion here."; return }
        let index = patrols.indices.min { patrols[$0].position.distance(to: tile.point) < patrols[$1].position.distance(to: tile.point) }!
        patrols[index].distraction = 4
        patrols[index].distractionPoint = tile.point
        decoyAvailable = false
        message = "A distant tap. Four seconds of opportunity."
    }

    func tick(_ delta: Double) {
        guard state == .active, !paused else { return }
        let dt = max(0, min(delta, 0.05))
        elapsed += dt
        for index in patrols.indices {
            if patrols[index].distraction > 0, let target = patrols[index].distractionPoint {
                patrols[index].distraction -= dt
                patrols[index].angle = atan2(target.y - patrols[index].position.y, target.x - patrols[index].position.x)
            } else if patrols[index].wait > 0 { patrols[index].wait -= dt }
            else {
                let target = patrols[index].route[patrols[index].next].point
                let p = patrols[index].position
                patrols[index].angle = atan2(target.y - p.y, target.x - p.x)
                let distance = p.distance(to: target)
                if distance < dt * 1.1 {
                    patrols[index].position = target
                    patrols[index].next = (patrols[index].next + 1) % patrols[index].route.count
                    patrols[index].wait = 1.2
                } else {
                    patrols[index].position = Position(x: p.x + cos(patrols[index].angle) * dt * 1.1, y: p.y + sin(patrols[index].angle) * dt * 1.1)
                }
            }
        }
        if let target = path.first?.point {
            let distance = player.distance(to: target)
            let travel = dt * (carrying == nil ? 3 : 2.1)
            if distance <= travel { player = target; path.removeFirst() }
            else { player = Position(x: player.x + (target.x - player.x) / distance * travel, y: player.y + (target.y - player.y) / distance * travel) }
        }
        let watched = observed(player)
        alarm = min(1, max(0, alarm + dt * (watched ? 0.5 : -0.25)))
        peakAlarm = max(peakAlarm, alarm)
        if watched { message = "You are in sight. Find cover!" }
        if var action = interaction {
            let objectPoint = action.placing ? level.exhibits.first { $0.id == action.id }!.destination.point : positions[action.id]!.point
            if watched || observed(objectPoint) { interaction = nil; message = "Interrupted. Wait for a clear moment." }
            else {
                action.elapsed += dt
                interaction = action
                if action.elapsed >= 1 {
                    if action.placing { delivered.insert(action.id); positions[action.id] = level.exhibits.first { $0.id == action.id }!.destination; carrying = nil }
                    else { carrying = action.id }
                    interaction = nil
                    message = delivered.count == level.exhibits.count ? "Everything is in place. Return to the exit." : "Quietly done. Keep moving."
                }
            }
        }
        if alarm >= 1 { state = .lost; interaction = nil; path = [] }
        else if delivered.count == level.exhibits.count && player.distance(to: level.exit.point) < 0.6 { state = .won }
    }
}
