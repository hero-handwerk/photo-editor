//
//  PhotoEditor+Drawing.swift
//  Photo Editor
//
//  Created by Mohamed Hamed on 6/16/17.
//
//
import UIKit

extension PhotoEditorViewController {
    
    override public func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?){
        coloredLines.append([ColoredPoint]())
        
        if isDrawing {
            swiped = false
            if let touch = touches.first {
                lastPoint = touch.location(in: self.canvasImageView)
            }
        }
            //Hide stickersVC if clicked outside it
        else if let stickersViewController = self.stickersViewController {
            if let touch = touches.first {
                let location = touch.location(in: self.view)
                if !stickersViewController.view.frame.contains(location) {
                    removeStickersView()
                }
            }
        }
        
        guard var firstColoredLine = coloredLines.popLast() else { return }
        firstColoredLine.append(ColoredPoint(point: lastPoint, color: drawColor))
        coloredLines.append(firstColoredLine)
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>,
                                      with event: UIEvent?){
        if isDrawing {
            // 6
            swiped = true
            if let touch = touches.first {
                let currentPoint = touch.location(in: canvasImageView)
                drawLineFrom(lastPoint, toPoint: currentPoint, withColor: drawColor)
                
                guard var lastColoredLine = coloredLines.popLast() else { return }
                lastColoredLine.append(ColoredPoint(point: currentPoint, color: drawColor))
                coloredLines.append(lastColoredLine)
                
                // 7
                lastPoint = currentPoint
            }
        }
    }
    
    override public func touchesEnded(_ touches: Set<UITouch>,
                                      with event: UIEvent?){
        if isDrawing {
            if !swiped {
                // draw a single point
                drawLineFrom(lastPoint, toPoint: lastPoint, withColor: drawColor)
            }
        }
        addLineUndoActionRegister()
        manageBarButtonVisibility()
    }
    
    func draw(_ coloredLines: [coloredLine]) {
        coloredLines.forEach { line in
            
            for i in 1 ..< line.count {
                guard let oldPoint = line[i-1].point, let newPoint = line[i].point, let color = line[i].color else { return }
                drawLineFrom(oldPoint, toPoint: newPoint, withColor: color)
            }
        }
    }
    
    func drawLineFrom(_ fromPoint: CGPoint, toPoint: CGPoint, withColor color: UIColor) {
        // 1
        let canvasSize = canvasImageView.frame.integral.size
        UIGraphicsBeginImageContextWithOptions(canvasSize, false, 0)
        if let context = UIGraphicsGetCurrentContext() {
            canvasImageView.image?.draw(in: CGRect(x: 0, y: 0, width: canvasSize.width, height: canvasSize.height))
            // 2
            context.move(to: CGPoint(x: fromPoint.x, y: fromPoint.y))
            context.addLine(to: CGPoint(x: toPoint.x, y: toPoint.y))
            // 3
            context.setLineCap( CGLineCap.round)
            context.setLineWidth(5.0)
            context.setStrokeColor(color.cgColor)
            context.setBlendMode(CGBlendMode.normal)
            // 4
            context.strokePath()
            // 5
            canvasImageView.image = UIGraphicsGetImageFromCurrentImageContext()
        }
        UIGraphicsEndImageContext()
    }
    
}

// MARK: - UndoManager
extension PhotoEditorViewController {
    func addLineUndoActionRegister() {
        undoManager?.registerUndo(withTarget: self, handler: { _ in
            self.removeLastLine()
            self.removeLineUndoActionRegister()
        })
    }
    
    func removeLineUndoActionRegister() {
        undoManager?.registerUndo(withTarget: self, handler: { _ in
            self.addLastLine()
            self.addLineUndoActionRegister()
        })
    }
    
    func removeLastLine() {
        guard let pendingColoredLine = coloredLines.popLast() else { return }
        removedLines.append(pendingColoredLine)
        
        canvasImageView.image = nil
        for subview in canvasImageView.subviews {
            subview.removeFromSuperview()
        }
        draw(coloredLines)
    }
    
    func addLastLine() {
        guard let pendingColoredLine = removedLines.popLast() else { return }
        coloredLines.append(pendingColoredLine)
        
        canvasImageView.image = nil
        for subview in canvasImageView.subviews {
            subview.removeFromSuperview()
        }
        draw(coloredLines)
    }
}


struct ColoredPoint {
    var point: CGPoint?
    var color: UIColor?
}
