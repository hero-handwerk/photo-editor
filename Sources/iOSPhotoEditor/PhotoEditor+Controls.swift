//
//  PhotoEditor+Controls.swift
//  Pods
//
//  Created by Mohamed Hamed on 6/16/17.
//
//

import Foundation
import UIKit

extension PhotoEditorViewController {

    // MARK: - Controls
    public enum Controls: UInt, CaseIterable {
        case save = 0
        case share
        case crop
        case sticker
        case draw
        case text
        case clear
        case reset
    }

    @IBAction func cancelButtonTapped(_ sender: UIBarButtonItem) {
        guard undoManager?.canUndo == true && isDrawing else {
            cancel()
            return
        }
        let alert = UIAlertController( title: "Möchten Sie wirklich alle Markierungen verwerfen?", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Änderungen verwerfen", style: .destructive) { [weak self] _ in
            self?.cancel()
        })
        let actionStyle: UIAlertAction.Style = UIDevice.current.userInterfaceIdiom == .pad ? .default : .cancel
        alert.addAction(UIAlertAction(title: "Weiter bearbeiten", style: actionStyle))
        alert.popoverPresentationController?.barButtonItem = sender
        present(alert, animated: true, completion: nil)
    }

    @IBAction func cropButtonTapped(_ sender: Any) {
        let controller = CropViewController()
        controller.delegate = self
        controller.image = imageData?.image
        let navController = UINavigationController(rootViewController: controller)

        navController.navigationBar.tintColor = navigationController?.navigationBar.tintColor
        navController.navigationBar.barTintColor = navigationController?.navigationBar.barTintColor
        navController.navigationBar.isTranslucent = navigationController?.navigationBar.isTranslucent ?? false

        navController.toolbar.tintColor = navigationController?.toolbar.tintColor
        navController.toolbar.barTintColor = navigationController?.toolbar.barTintColor
        navController.toolbar.isTranslucent = navigationController?.toolbar.isTranslucent ?? false

        present(navController, animated: true, completion: nil)
        
        tracker?.track(event: .crop)
    }

    @IBAction func stickersButtonTapped(_ sender: Any) {
        addStickersViewController()
    }

    @IBAction func drawButtonTapped(_ sender: Any) {
        isDrawing = true
        canvasImageView.isUserInteractionEnabled = false
        showToolbar(show: false)
        showDoneButton(show: true)
        showDrawActionControlButtons(show: true)
        showColorPicker(show: true)
        
        tracker?.track(event: .draw)
    }

    @IBAction func textButtonTapped(_ sender: Any) {
        let textView = UITextView(frame: CGRect(x: 0, y: canvasImageView.center.y,
                                                width: UIScreen.main.bounds.width, height: 30))
        
        textView.textAlignment = .center
        textView.font = UIFont(name: "Helvetica", size: 30)
        textView.textColor = textColor
        textView.layer.shadowColor = UIColor.black.cgColor
        textView.layer.shadowOffset = CGSize(width: 1.0, height: 0.0)
        textView.layer.shadowOpacity = 0.2
        textView.layer.shadowRadius = 1.0
        textView.layer.backgroundColor = UIColor.clear.cgColor
        textView.autocorrectionType = .no
        textView.isScrollEnabled = false
        textView.delegate = self
        self.canvasImageView.addSubview(textView)
        addGestures(view: textView)
        textView.becomeFirstResponder()
        
        tracker?.track(event: .text)
    }
    
    @IBAction func doneButtonTapped(_ sender: Any) {
        view.endEditing(true)
        
        showDrawActionControlButtons(show: false)
        showDoneButton(show: false)
        showColorPicker(show: false) {
            self.showToolbar(show: true)
        }
        canvasImageView.isUserInteractionEnabled = true
        isDrawing = false
    }
    
    @IBAction func saveButtonTapped(_ sender: AnyObject) {
        UIImageWriteToSavedPhotosAlbum(canvasView.toImage(),self, #selector(PhotoEditorViewController.image(_:withPotentialError:contextInfo:)), nil)
    }
    
    @IBAction func shareButtonTapped(_ sender: UIBarButtonItem) {
        let activityController: UIActivityViewController
        
        if let mailActivity = photoEditorDelegate?.mailActivity(emailRecipient: imageData?.emailRecipientForSharing ?? "") {
            activityController = UIActivityViewController(activityItems: [canvasView.toImage()], applicationActivities: [mailActivity])
            activityController.excludedActivityTypes = [.mail]
        } else {
            activityController = UIActivityViewController(activityItems: [canvasView.toImage()], applicationActivities: nil)
        }
        
        activityController.popoverPresentationController?.barButtonItem = sender
        present(activityController, animated: true, completion: nil)
        
        tracker?.track(event: .share)
    }
    
    @IBAction func clearButtonTapped(_ sender: AnyObject) {
        //clear drawing
        canvasImageView.image = nil
        //clear stickers and textviews
        for subview in canvasImageView.subviews {
            subview.removeFromSuperview()
        }
        
        backupColoredLines = coloredLines
        coloredLines = [coloredLine]()
        removedLines = [coloredLine]()
        canResetLines = undoManager?.canUndo == true
        addControls(animated: false)
        
        tracker?.track(event: .revert)
    }
    
    @IBAction func resetButtonTapped(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "Möchten Sie wirklich alle Markierungen wiederherstellen?", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Abbrechen", style: .destructive))
        
        let actionStyle: UIAlertAction.Style = UIDevice.current.userInterfaceIdiom == .pad ? .default : .cancel
        alert.addAction(UIAlertAction(title: "Wiederherstellen", style: actionStyle) { [weak self] _ in
            self?.reset()
        })
        alert.popoverPresentationController?.barButtonItem = sender
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func continueButtonPressed(_ sender: Any) {
        clearUndoManager()
        
        let img = self.canvasView.toImage()
        photoEditorDelegate?.doneEditing(image: img)
        self.dismiss(animated: true, completion: nil)
        
        tracker?.track(event: .done)
    }
    
    @IBAction func undoButtonTapped(_ sender: Any) {
        if undoManager?.canUndo == true {
            undoManager?.undo()
        }
        manageBarButtonVisibility()
    }
    
    @IBAction func redoButtonTapped(_ sender: Any) {
        if undoManager?.canRedo == true {
            undoManager?.redo()
        }
        manageBarButtonVisibility()
    }

    //MAKR: helper methods
    
    @objc func image(_ image: UIImage, withPotentialError error: NSErrorPointer, contextInfo: UnsafeRawPointer) {
        let alert = UIAlertController(title: "Image Saved", message: "Image successfully saved to Photos library", preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    func addControls(animated: Bool = true) {
        var barButtonItems = [UIBarButtonItem]()
        let visibleControls = Set(PhotoEditorViewController.Controls.allCases).subtracting(Set(hiddenControls))
                .sorted { $0.rawValue < $1.rawValue  }
        for control in visibleControls {
            switch control {
            case .save:
                barButtonItems.append(flexibleSpaceBarButtonItem())
                barButtonItems.append(saveButton)
            case .share:
                barButtonItems.append(flexibleSpaceBarButtonItem())
                barButtonItems.append(shareButton)
            case .crop:
                barButtonItems.append(flexibleSpaceBarButtonItem())
                barButtonItems.append(cropButton)
            case .sticker:
                barButtonItems.append(flexibleSpaceBarButtonItem())
                barButtonItems.append(stickerButton)
            case .draw:
                barButtonItems.append(flexibleSpaceBarButtonItem())
                barButtonItems.append(drawButton)
            case .text:
                barButtonItems.append(flexibleSpaceBarButtonItem())
                barButtonItems.append(textButton)
            case .clear:
                if !canResetLines {
                    barButtonItems.append(flexibleSpaceBarButtonItem())
                    barButtonItems.append(clearButton)
                }
            case .reset:
                if canResetLines {
                    barButtonItems.append(flexibleSpaceBarButtonItem())
                    barButtonItems.append(resetButton)
                }
            }
        }

        if barButtonItems.isEmpty { return }
        barButtonItems.append(flexibleSpaceBarButtonItem())

        setToolbarItems(barButtonItems, animated: animated)
    }

    private func flexibleSpaceBarButtonItem() -> UIBarButtonItem {
        UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
    }
    
    private func clearUndoManager() {
        undoManager?.removeAllActions(withTarget: self)
    }
    
    func manageBarButtonVisibility() {
        undoButton.isEnabled = undoManager?.canUndo ?? false
        redoButton.isEnabled = undoManager?.canRedo ?? false
    }
    
    func cancel() {
        clearUndoManager()
        
        photoEditorDelegate?.canceledEditing()
        dismiss(animated: true, completion: nil)
        
        tracker?.track(event: .cancel)
    }
    
    func reset() {
        canvasImageView.image = nil
        for subview in canvasImageView.subviews {
            subview.removeFromSuperview()
        }
        draw { cgContext in
            drawColoredLines(backupColoredLines, cgContext: cgContext)
        }
        coloredLines = backupColoredLines
        canResetLines = false
        addControls(animated: false)
        
        tracker?.track(event: .reset)
    }
}
