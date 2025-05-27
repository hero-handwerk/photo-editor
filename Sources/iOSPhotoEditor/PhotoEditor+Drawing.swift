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
        if isDrawing {
            swiped = false
            if let touch = touches.first {
                lastPoint = touch.location(in: self.canvasImageView)
            }
            
            let firstColoredLine = [ColoredPoint(point: lastPoint, color: drawColor)]
            coloredLines.append(firstColoredLine)
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
    }
    
    override public func touchesMoved(_ touches: Set<UITouch>,
                                      with event: UIEvent?){
        if isDrawing {
            // 6
            swiped = true
            if let touch = touches.first {
                let currentPoint = touch.location(in: canvasImageView)
                draw { cgContext in
                    drawLineFrom(lastPoint, toPoint: currentPoint, withColor: drawColor, cgContext: cgContext)
                }
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
        guard isDrawing else { return }
        
        if !swiped {
            // draw a single point
            draw { cgContext in
                drawLineFrom(lastPoint, toPoint: lastPoint, withColor: drawColor, cgContext: cgContext)
            }
        }
        addLineUndoActionRegister()
        manageBarButtonVisibility()
    }
    
    func draw(drawAction: (CGContext) -> Void) {
        let canvasSize = canvasImageView.frame.integral.size
        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        
        canvasImageView.image = renderer.image { context in
            let cgContext = context.cgContext
            
            canvasImageView.image?.draw(in: CGRect(origin: .zero, size: canvasSize))
            
            cgContext.setLineCap(.round)
            cgContext.setLineWidth(5.0)
            cgContext.setBlendMode(.normal)
            
            drawAction(cgContext)
        }
    }
    
    func drawColoredLines(_ coloredLines: [coloredLine], cgContext: CGContext) {
        coloredLines.forEach { line in
            
            for i in 1 ..< line.count {
                guard let oldPoint = line[i-1].point,
                      let newPoint = line[i].point,
                      let color = line[i].color
                else { return }
                
                drawLineFrom(oldPoint, toPoint: newPoint, withColor: color, cgContext: cgContext)
            }
        }
    }
    
    func drawLineFrom(_ fromPoint: CGPoint, toPoint: CGPoint, withColor color: UIColor, cgContext: CGContext) {
        cgContext.move(to: fromPoint)
        cgContext.addLine(to: toPoint)
        cgContext.setStrokeColor(color.cgColor)
        cgContext.strokePath()
    }
    
}

// MARK: - UndoManager
extension PhotoEditorViewController {
    func addLineUndoActionRegister() {
        undoManager?.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.removeLastLine()
            self?.removeLineUndoActionRegister()
        })
    }
    
    func removeLineUndoActionRegister() {
        undoManager?.registerUndo(withTarget: self, handler: { [weak self] _ in
            self?.addLastLine()
            self?.addLineUndoActionRegister()
        })
    }
    
    func removeLastLine() {
        guard let pendingColoredLine = coloredLines.popLast() else { return }
        removedLines.append(pendingColoredLine)
        
        canvasImageView.image = nil
        for subview in canvasImageView.subviews {
            subview.removeFromSuperview()
        }
        draw { cgContext in
            drawColoredLines(coloredLines, cgContext: cgContext)
        }
    }
    
    func addLastLine() {
        guard let pendingColoredLine = removedLines.popLast() else { return }
        coloredLines.append(pendingColoredLine)
        
        canvasImageView.image = nil
        for subview in canvasImageView.subviews {
            subview.removeFromSuperview()
        }
        draw { cgContext in
            drawColoredLines(coloredLines, cgContext: cgContext)
        }
    }
}


struct ColoredPoint {
    var point: CGPoint?
    var color: UIColor?
}
