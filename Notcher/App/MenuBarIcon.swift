//
//  MenuBarIcon.swift
//  Notcher
//
//  Menu bar icon for Notcher - notch shape without logo
//

import AppKit

/// Creates the Notcher menu bar icon - a notch silhouette
func createNotcherMenuBarIcon() -> NSImage {
    let iconWidth: CGFloat = 28
    let iconHeight: CGFloat = 18
    let earSize: CGFloat = 4
    let cornerRadius: CGFloat = 6

    let image = NSImage(size: NSSize(width: iconWidth, height: iconHeight), flipped: false) { rect in
        // Draw left ear
        let leftEarPath = NSBezierPath()
        leftEarPath.move(to: NSPoint(x: earSize, y: iconHeight))
        leftEarPath.line(to: NSPoint(x: earSize, y: iconHeight - earSize))
        leftEarPath.appendArc(
            withCenter: NSPoint(x: 0, y: iconHeight - earSize),
            radius: earSize,
            startAngle: 0,
            endAngle: 90,
            clockwise: false
        )
        leftEarPath.close()
        NSColor.black.setFill()
        leftEarPath.fill()

        // Draw right ear
        let rightEarPath = NSBezierPath()
        rightEarPath.move(to: NSPoint(x: iconWidth - earSize, y: iconHeight))
        rightEarPath.line(to: NSPoint(x: iconWidth - earSize, y: iconHeight - earSize))
        rightEarPath.appendArc(
            withCenter: NSPoint(x: iconWidth, y: iconHeight - earSize),
            radius: earSize,
            startAngle: 180,
            endAngle: 90,
            clockwise: true
        )
        rightEarPath.close()
        NSColor.black.setFill()
        rightEarPath.fill()

        // Draw main notch body
        let bodyRect = NSRect(x: earSize, y: 0, width: iconWidth - (earSize * 2), height: iconHeight)
        let bodyPath = NSBezierPath(roundedRect: bodyRect, xRadius: cornerRadius, yRadius: cornerRadius)
        // Square off the top corners
        let topRect = NSRect(x: earSize, y: iconHeight - cornerRadius, width: iconWidth - (earSize * 2), height: cornerRadius)
        bodyPath.append(NSBezierPath(rect: topRect))
        NSColor.black.setFill()
        bodyPath.fill()

        return true
    }

    image.isTemplate = true
    return image
}
