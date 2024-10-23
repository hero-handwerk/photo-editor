//
//  Protocols.swift
//  Photo Editor
//
//  Created by Mohamed Hamed on 6/15/17.
//
//

import Foundation
import UIKit
/**
 - didSelectView
 - didSelectImage
 - stickersViewDidDisappear
 */

@MainActor
public protocol PhotoEditorDelegate: class {
    /**
     - Parameter image: edited Image
     */
    func doneEditing(image: UIImage)
    /**
     StickersViewController did Disappear
     */
    func canceledEditing()

    /// Retrieve custom Mail activity to be able to set the recipient address
    func mailActivity(emailRecipient: String) -> UIActivity?
}


/**
 - didSelectView
 - didSelectImage
 - stickersViewDidDisappear
 */
protocol StickersViewControllerDelegate: class {
    /**
     - Parameter view: selected view from StickersViewController
     */
    func didSelectView(view: UIView)
    /**
     - Parameter image: selected Image from StickersViewController
     */
    func didSelectImage(image: UIImage)
    /**
     StickersViewController did Disappear
     */
    func stickersViewDidDisappear()
}

/**
 - didSelectColor
 */
protocol ColorDelegate: class {
    func didSelectColor(color: UIColor)
}
