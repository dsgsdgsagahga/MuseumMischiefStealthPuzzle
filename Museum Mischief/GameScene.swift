import SpriteKit

final class GameScene: SKScene {
    weak var engine: GameEngine?
    var onTap: ((Tile) -> Void)?
    var reducedEffects = false
    private let world = SKNode()
    private var cell: CGFloat = 40
    private var offset = CGPoint.zero
    private var built = false
    private let dynamicLayer = SKNode()
    private let ink = SKColor(red: 0.08, green: 0.15, blue: 0.24, alpha: 1)
    private let gold = SKColor(red: 0.94, green: 0.75, blue: 0.38, alpha: 1)
    private let teal = SKColor(red: 0.27, green: 0.85, blue: 0.77, alpha: 1)

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.035, green: 0.07, blue: 0.12, alpha: 1)
        addChild(world)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func didChangeSize(_ oldSize: CGSize) { built = false; render() }

    private func point(_ p: Position) -> CGPoint { CGPoint(x: CGFloat(p.x) * cell, y: CGFloat(p.y) * cell) }
    private func shape(_ rect: CGRect, color: SKColor, radius: CGFloat = 6) -> SKShapeNode {
        let node = SKShapeNode(rect: rect, cornerRadius: radius)
        node.fillColor = color
        node.strokeColor = color.withAlphaComponent(0.6)
        return node
    }
    private func text(_ value: String, at p: CGPoint, color: SKColor, size: CGFloat = 12) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        node.text = value
        node.fontSize = size
        node.fontColor = color
        node.position = p
        return node
    }

    func render() {
        guard let engine else { return }
        if !built {
            world.removeAllChildren()
            for index in 0..<8 {
                let border = SKShapeNode(rect: CGRect(x: CGFloat(index) * size.width / 8, y: -size.height, width: 1, height: size.height * 3))
                border.strokeColor = gold.withAlphaComponent(0.06)
                world.addChild(border)
            }
            cell = min(size.width / 12, size.height / 16)
            offset = CGPoint(x: (size.width - cell * 12) / 2, y: (size.height - cell * 16) / 2)
            world.position = offset
            for y in 0..<16 {
                for x in 0..<12 {
                    let tile = Tile(x: x, y: y)
                    let wall = engine.level.walls.contains(tile)
                    let rect = CGRect(x: CGFloat(x) * cell + 1, y: CGFloat(y) * cell + 1, width: cell - 2, height: cell - 2)
                    let node = shape(rect, color: wall ? ink : SKColor(white: (x + y) % 2 == 0 ? 0.105 : 0.12, alpha: 1), radius: wall ? 3 : 1)
                    world.addChild(node)
                    if wall && x > 0 && x < 11 && y > 0 && y < 15 {
                        world.addChild(text("▰", at: point(tile.point), color: gold.withAlphaComponent(0.5), size: cell * 0.4))
                    }
                }
            }
            let exit = point(engine.level.exit.point)
            let exitNode = shape(CGRect(x: exit.x - cell * 0.45, y: exit.y - cell * 0.45, width: cell * 0.9, height: cell * 0.9), color: teal.withAlphaComponent(0.25))
            world.addChild(exitNode)
            world.addChild(text("EXIT", at: CGPoint(x: exit.x, y: exit.y - 4), color: teal, size: cell * 0.23))
            for exhibit in engine.level.exhibits {
                let p = point(exhibit.destination.point)
                let ring = SKShapeNode(circleOfRadius: cell * 0.38)
                ring.position = p
                ring.strokeColor = teal
                ring.fillColor = teal.withAlphaComponent(0.08)
                ring.lineWidth = 2
                world.addChild(ring)
                world.addChild(text("\(exhibit.id + 1)", at: CGPoint(x: p.x, y: p.y - cell * 0.1), color: teal, size: cell * 0.35))
            }
            world.addChild(dynamicLayer)
            built = true
        }
        dynamicLayer.removeAllChildren()
        for watcher in engine.watchers {
            let path = CGMutablePath()
            path.move(to: point(watcher.position))
            for index in 0...36 {
                let angle = watcher.angle - watcher.aperture / 2 + watcher.aperture * Double(index) / 36
                var distance = 0.0
                while distance < watcher.range {
                    let next = distance + 0.08
                    let p = Position(x: watcher.position.x + cos(angle) * next, y: watcher.position.y + sin(angle) * next)
                    if engine.level.walls.contains(p.tile) { break }
                    distance = next
                }
                path.addLine(to: point(Position(x: watcher.position.x + cos(angle) * distance, y: watcher.position.y + sin(angle) * distance)))
            }
            path.closeSubpath()
            let cone = SKShapeNode(path: path)
            cone.fillColor = SKColor.systemRed.withAlphaComponent(reducedEffects ? 0.12 : 0.19)
            cone.strokeColor = SKColor.systemRed.withAlphaComponent(0.3)
            dynamicLayer.addChild(cone)
        }
        for tile in engine.path {
            let dot = SKShapeNode(circleOfRadius: cell * 0.045)
            dot.position = point(tile.point)
            dot.fillColor = teal
            dot.strokeColor = .clear
            dynamicLayer.addChild(dot)
        }
        for exhibit in engine.level.exhibits where engine.carrying != exhibit.id {
            guard let tile = engine.positions[exhibit.id] else { continue }
            artifact(style: exhibit.style, at: point(tile.point), complete: engine.delivered.contains(exhibit.id))
            let p = point(tile.point)
            dynamicLayer.addChild(text("\(exhibit.id + 1)", at: CGPoint(x: p.x, y: p.y + cell * 0.32), color: gold, size: cell * 0.25))
        }
        for patrol in engine.patrols {
            let p = point(patrol.position)
            let guardNode = shape(CGRect(x: -cell * 0.22, y: -cell * 0.25, width: cell * 0.44, height: cell * 0.5), color: SKColor.systemRed)
            guardNode.position = p
            guardNode.zRotation = CGFloat(patrol.angle - .pi / 2)
            dynamicLayer.addChild(guardNode)
            dynamicLayer.addChild(text("!", at: CGPoint(x: p.x, y: p.y - 3), color: .white, size: cell * 0.25))
        }
        for camera in engine.level.cameras {
            let p = point(camera.tile.point)
            dynamicLayer.addChild(shape(CGRect(x: p.x - cell * 0.22, y: p.y - cell * 0.12, width: cell * 0.44, height: cell * 0.24), color: .lightGray, radius: 3))
        }
        let player = SKShapeNode(circleOfRadius: cell * 0.23)
        player.position = point(engine.player)
        player.fillColor = teal
        player.strokeColor = .white
        player.lineWidth = 2
        dynamicLayer.addChild(player)
        let cap = shape(CGRect(x: -cell * 0.18, y: cell * 0.04, width: cell * 0.36, height: cell * 0.1), color: ink, radius: 2)
        player.addChild(cap)
        if let id = engine.carrying { artifact(style: id, at: CGPoint(x: player.position.x + cell * 0.25, y: player.position.y + cell * 0.3), complete: false) }
    }

    private func artifact(style: Int, at p: CGPoint, complete: Bool) {
        let plinth = shape(CGRect(x: p.x - cell * 0.3, y: p.y - cell * 0.27, width: cell * 0.6, height: cell * 0.12), color: complete ? teal : ink)
        dynamicLayer.addChild(plinth)
        let path = CGMutablePath()
        if style == 0 {
            path.move(to: CGPoint(x: -0.12, y: 0.25))
            path.addLines(between: [CGPoint(x: 0.12, y: 0.25), CGPoint(x: 0.08, y: 0.08), CGPoint(x: 0.22, y: -0.1), CGPoint(x: 0.13, y: -0.23), CGPoint(x: -0.13, y: -0.23), CGPoint(x: -0.22, y: -0.1), CGPoint(x: -0.08, y: 0.08)])
        } else if style == 1 {
            path.move(to: CGPoint(x: -0.22, y: 0.25))
            path.addLines(between: [CGPoint(x: 0, y: 0.12), CGPoint(x: 0.22, y: 0.25), CGPoint(x: 0.18, y: -0.2), CGPoint(x: -0.18, y: -0.2)])
        } else {
            path.addEllipse(in: CGRect(x: -0.13, y: 0, width: 0.26, height: 0.3))
            path.addRect(CGRect(x: -0.22, y: -0.22, width: 0.44, height: 0.19))
        }
        path.closeSubpath()
        var transform = CGAffineTransform(scaleX: cell, y: cell)
        let node = SKShapeNode(path: path.copy(using: &transform)!)
        node.position = p
        node.fillColor = gold
        node.strokeColor = .white.withAlphaComponent(0.5)
        dynamicLayer.addChild(node)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let p = touch.location(in: world)
        onTap?(Tile(x: Int(floor(p.x / cell)), y: Int(floor(p.y / cell))))
    }
}
