import SwiftUI

// MARK: - 九宫格手势解锁

struct PatternLockView: View {
    @Binding var pattern: [Int]
    var isDisabled: Bool = false
    var onChanged: (([Int]) -> Void)? = nil
    var onCompleted: (([Int]) -> Void)? = nil

    @State private var currentLocation: CGPoint?
    @State private var sessionPoints: [Int] = []
    @State private var isDragging = false

    private let numberOfDots = 9
    private let columns = 3
    private let hitSlop: CGFloat = 40

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let centers = dotCenters(in: size)

            ZStack {
                ForEach(0..<numberOfDots, id: \.self) { index in
                    dotView(at: centers[index], diameter: size / CGFloat(columns) * 0.20, isActive: activeDots.contains(index))
                }
                lines(centers: centers)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        guard !isDisabled else { return }
                        handle(value.location, centers: centers)
                    }
                    .onEnded { _ in
                        guard !isDisabled else { return }
                        finish()
                    }
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .opacity(isDisabled ? 0.55 : 1)
        .animation(.easeOut(duration: 0.15), value: pattern)
    }

    private var activeDots: Set<Int> {
        if isDragging {
            return Set(sessionPoints)
        }
        return Set(pattern)
    }

    private func dotCenters(in size: CGFloat) -> [CGPoint] {
        let spacing = size / CGFloat(columns)
        let inset = spacing / 2
        var centers: [CGPoint] = []
        for row in 0..<columns {
            for column in 0..<columns {
                centers.append(
                    CGPoint(
                        x: inset + CGFloat(column) * spacing,
                        y: inset + CGFloat(row) * spacing
                    )
                )
            }
        }
        return centers
    }

    private func dotView(at point: CGPoint, diameter: CGFloat, isActive: Bool) -> some View {
        Circle()
            .fill(isActive ? Theme.violet : Color.white.opacity(0.16))
            .overlay(
                Circle()
                    .stroke(isActive ? Theme.violet.opacity(0.5) : Color.clear, lineWidth: 9)
            )
            .frame(width: diameter, height: diameter)
            .position(point)
    }

    private func lines(centers: [CGPoint]) -> some View {
        let points = visiblePoints(centers: centers)
        return Path { path in
            guard let first = points.first else { return }
            path.addEllipse(in: CGRect(x: first.x - 17, y: first.y - 17, width: 34, height: 34))
            guard points.count > 1 else { return }
            path.move(to: first)
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
        }
        .stroke(
            Theme.violet.opacity(0.75),
            style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
        )
        .allowsHitTesting(false)
    }

    private func visiblePoints(centers: [CGPoint]) -> [CGPoint] {
        var points = activeDots.sorted().map { centers[$0] }
        if isDragging, let location = currentLocation, let last = points.last {
            points.append(CGPoint(
                x: last.x + (location.x - last.x) * 0.75,
                y: last.y + (location.y - last.y) * 0.75
            ))
        }
        return points
    }

    // MARK: 手势处理

    private func nearestDot(to location: CGPoint, centers: [CGPoint]) -> Int? {
        var bestIndex: Int?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (index, center) in centers.enumerated() {
            let dx = center.x - location.x
            let dy = center.y - location.y
            let distance = (dx * dx + dy * dy).squareRoot()
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        guard let index = bestIndex, bestDistance <= hitSlop else { return nil }
        return index
    }

    private func handle(_ location: CGPoint, centers: [CGPoint]) {
        if !isDragging {
            isDragging = true
            sessionPoints = []
            pattern = []
        }
        currentLocation = location

        guard let index = nearestDot(to: location, centers: centers) else { return }
        guard !sessionPoints.contains(index) else { return }
        sessionPoints.append(index)
        pattern = sessionPoints
        onChanged?(sessionPoints)
    }

    private func finish() {
        let final = sessionPoints
        isDragging = false
        currentLocation = nil
        sessionPoints = []
        if final.count >= 4 {
            onCompleted?(final)
        } else {
            pattern = []
        }
    }
}
