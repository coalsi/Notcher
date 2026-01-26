//
//  CornerShape.swift
//  Notcher
//
//  Shape definitions for screen corner overlays
//

import SwiftUI

enum CornerPosition: CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

struct CornerShape: Shape {
    let position: CornerPosition

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Fill the entire rect, then cut out a quarter circle from the inner corner
        switch position {
        case .topLeft:
            // Quarter circle cut from bottom-right corner of rect (toward screen center)
            // Arc center at bottom-right of rect
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addArc(
                center: CGPoint(x: rect.maxX, y: rect.maxY),
                radius: rect.width,
                startAngle: .degrees(270),
                endAngle: .degrees(180),
                clockwise: true
            )
            path.closeSubpath()

        case .topRight:
            // Quarter circle cut from bottom-left corner of rect (toward screen center)
            // Arc center at bottom-left of rect
            path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addArc(
                center: CGPoint(x: rect.minX, y: rect.maxY),
                radius: rect.width,
                startAngle: .degrees(270),
                endAngle: .degrees(0),
                clockwise: false
            )
            path.closeSubpath()

        case .bottomLeft:
            // Quarter circle cut from top-right corner of rect (toward screen center)
            // Arc center at top-right of rect
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addArc(
                center: CGPoint(x: rect.maxX, y: rect.minY),
                radius: rect.width,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
            path.closeSubpath()

        case .bottomRight:
            // Quarter circle cut from top-left corner of rect (toward screen center)
            // Arc center at top-left of rect
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addArc(
                center: CGPoint(x: rect.minX, y: rect.minY),
                radius: rect.width,
                startAngle: .degrees(90),
                endAngle: .degrees(0),
                clockwise: true
            )
            path.closeSubpath()
        }

        return path
    }
}

struct CornerView: View {
    let position: CornerPosition
    let size: CGFloat

    var body: some View {
        CornerShape(position: position)
            .fill(Color.black)
            .frame(width: size, height: size)
    }
}
