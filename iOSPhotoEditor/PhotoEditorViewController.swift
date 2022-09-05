//
//  ViewController.swift
//  Photo Editor
//
//  Created by Mohamed Hamed on 4/23/17.
//  Copyright © 2017 Mohamed Hamed. All rights reserved.
//

import UIKit

public protocol PhotoEditorTracker {
    func track(event: PhotoEditorViewController.Event)
}

public final class PhotoEditorViewController: UIViewController {
    public enum Event {
        case done
        case cancel
        case share
        case crop
        case draw
        case text
        case revert
        case reset
    }
    
    public struct ImageData {
        private(set) var image: UIImage?
        let emailRecipientForSharing: String?
        
        public init(image: UIImage?, emailRecipientForSharing: String?) {
            self.image = image
            self.emailRecipientForSharing = emailRecipientForSharing
        }
    
        public init(imageFileURL: URL, emailRecipientForSharing: String?) {
            if let data = try? Data(contentsOf: imageFileURL), let image = UIImage(data: data) {
                self.image = image
            }
            self.emailRecipientForSharing = emailRecipientForSharing
        }
    }

    /** holding the 2 imageViews original image and drawing & stickers */
    @IBOutlet weak var canvasView: UIView!
    //To hold the image
    @IBOutlet var imageView: UIImageView!
    @IBOutlet weak var imageViewHeightConstraint: NSLayoutConstraint!
    //To hold the drawings and stickers
    @IBOutlet weak var canvasImageView: UIImageView!

    @IBOutlet var cancelButton: UIBarButtonItem!
    @IBOutlet var continueButton: UIBarButtonItem!
    @IBOutlet var doneButton: UIBarButtonItem!

    @IBOutlet weak var deleteView: UIView!
    @IBOutlet weak var colorsCollectionView: UICollectionView!
    @IBOutlet weak var colorPickerView: UIView!
    @IBOutlet weak var colorPickerViewBottomConstraint: NSLayoutConstraint!
    
    //Controls
    @IBOutlet weak var cropButton: UIBarButtonItem!
    @IBOutlet weak var stickerButton: UIBarButtonItem!
    @IBOutlet weak var drawButton: UIBarButtonItem!
    @IBOutlet weak var textButton: UIBarButtonItem!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var shareButton: UIBarButtonItem!
    @IBOutlet var clearButton: UIBarButtonItem!
    @IBOutlet var undoButton: UIBarButtonItem!
    @IBOutlet var redoButton: UIBarButtonItem!
    @IBOutlet var resetButton: UIBarButtonItem!
    
    public static let storyboardForInit = UIStoryboard(
        name: "PhotoEditor",
        bundle: Bundle.iOSPhotoEditorResourceBundle
    )
    
    private(set) var imageData: ImageData? {
        didSet {
            if isViewLoaded {
                setImageView(image: imageData?.image)
            }
        }
    }
    private(set) var tracker: PhotoEditorTracker?
    /**
     Array of Stickers -UIImage- that the user will choose from
     */
    public var stickers : [UIImage] = []
    /**
     Array of Colors that will show while drawing or typing
     */
    public var colors  : [UIColor] = []
    
    public weak var photoEditorDelegate: PhotoEditorDelegate?
    var colorsCollectionViewDelegate: ColorsCollectionViewDelegate!
    
    // list of controls to be hidden
    public var hiddenControls : [PhotoEditorViewController.Controls] = []
    
    var drawColor: UIColor = UIColor.black
    var textColor: UIColor = UIColor.white
    var isDrawing: Bool = false
    var lastPoint: CGPoint!
    var swiped = false
    var lastPanPoint: CGPoint?
    var lastTextViewTransform: CGAffineTransform?
    var lastTextViewTransCenter: CGPoint?
    var lastTextViewFont:UIFont?
    var activeTextView: UITextView?
    var imageViewToPan: UIImageView?
    
    typealias coloredLine = [ColoredPoint]
    var coloredLines = [coloredLine]()
    var removedLines = [coloredLine]()
    var backupColoredLines = [coloredLine]()
    var canResetLines = false

    weak var stickersViewController: StickersViewController?
    
    public init?(
        coder: NSCoder,
        imageData: ImageData,
        delegate: PhotoEditorDelegate,
        tracker: PhotoEditorTracker
    ) {
        super.init(coder: coder)

        self.imageData = imageData
        self.photoEditorDelegate = delegate
        self.tracker = tracker
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        setImageView(image: imageData?.image)
        
        deleteView.layer.cornerRadius = deleteView.bounds.height / 2
        deleteView.layer.borderWidth = 2.0
        deleteView.layer.borderColor = UIColor.white.cgColor
        deleteView.clipsToBounds = true
        deleteView.tintColor = UIColor.white

        let edgePan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(screenEdgeSwiped))
        edgePan.edges = .bottom
        edgePan.delegate = self
        self.view.addGestureRecognizer(edgePan)
        
        NotificationCenter.default.addObserver(self,selector: #selector(keyboardWillChangeFrame(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        
        manageBarButtonVisibility()
        configureCollectionView()
        navigationItem.rightBarButtonItems = [continueButton]
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        showToolbar(show: true, animated: false)
    }

    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(
                alongsideTransition: { _ in self.colorsCollectionView.collectionViewLayout.invalidateLayout() },
                completion: { _ in }
        )
    }
    
    func configureCollectionView() {
        let layout: UICollectionViewFlowLayout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 30, height: 30)
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        colorsCollectionView.collectionViewLayout = layout
        colorsCollectionViewDelegate = ColorsCollectionViewDelegate()
        colorsCollectionViewDelegate.colorDelegate = self
        if !colors.isEmpty {
            colorsCollectionViewDelegate.colors = colors
        }
        colorsCollectionView.delegate = colorsCollectionViewDelegate
        colorsCollectionView.dataSource = colorsCollectionViewDelegate
        
        colorsCollectionView.register(
            UINib(nibName: String(describing: ColorCollectionViewCell.self), bundle: Bundle.iOSPhotoEditorResourceBundle),
            forCellWithReuseIdentifier: String(describing: ColorCollectionViewCell.self))
    }
    
    func setImageView(image: UIImage?) {
        imageView.image = image
        
        if
            let image = image,
            let size = image.suitableSize(widthLimit: UIScreen.main.bounds.width) {
            
            imageViewHeightConstraint.constant = size.height
        }
    }
    
    func showToolbar(show: Bool, animated: Bool = true) {
        let toolbarIsHidden = navigationController?.toolbar.isHidden ?? false
        if show {
            addControls(animated: animated && !toolbarIsHidden)
        }
        guard toolbarIsHidden == show else { return }
        navigationController?.setToolbarHidden(!show, animated: animated)
    }

    func showDoneButton(show: Bool) {
        if show {
            if navigationItem.rightBarButtonItem == doneButton { return }
            navigationItem.rightBarButtonItems = [doneButton]
        }
        else {
            if navigationItem.rightBarButtonItem == continueButton { return }
            navigationItem.setLeftBarButton(cancelButton, animated: true)
            navigationItem.setRightBarButton(continueButton, animated: true)
        }
    }
    
    func showDrawActionControlButtons(show: Bool) {
        if show {
            navigationItem.rightBarButtonItems?.append(redoButton)
            navigationItem.rightBarButtonItems?.append(undoButton)
        } else {
            navigationItem.rightBarButtonItems = nil
        }
    }

    func showDeleteView(show: Bool, completion: (() -> Void)? = nil) {
        guard deleteView.isHidden == show else {
            completion?()
            return
        }
        if show {
            deleteView.alpha = 0.0
            deleteView.isHidden = false
            UIView.animate(withDuration: 0.3,
                    delay: 0.2,
                    options: [.beginFromCurrentState, .curveEaseIn],
                    animations: {
                self.deleteView.alpha = 1.0
            }, completion: { _ in completion?() })
        }
        else {
            UIView.animate(withDuration: 0.3,
                    delay: 0,
                    options: [.beginFromCurrentState, .curveEaseOut],
                    animations: {
                        self.deleteView.alpha = 0.0
            }, completion: { _ in
                self.deleteView.isHidden = true
                completion?()
            })
        }
    }

    func showColorPicker(show: Bool, completion: (() -> Void)? = nil) {
        guard colorPickerView.isHidden == show else {
            completion?()
            return
        }
        if show {
            colorPickerView.alpha = 0.0
            colorPickerView.isHidden = false
            UIView.animate(withDuration: 0.3,
                    delay: 0.2,
                    options: [.beginFromCurrentState, .curveEaseIn],
                    animations: {
                        self.colorPickerView.alpha = 1.0
                    }, completion: { _ in completion?() })
        }
        else {
            UIView.animate(withDuration: 0.3,
                    delay: 0,
                    options: [.beginFromCurrentState, .curveEaseOut],
                    animations: {
                        self.colorPickerView.alpha = 0.0
                    }, completion: { _ in
                self.colorPickerView.isHidden = true
                completion?()
            })
        }
    }
}

extension PhotoEditorViewController: ColorDelegate {
    func didSelectColor(color: UIColor) {
        if isDrawing {
            self.drawColor = color
        } else if activeTextView != nil {
            activeTextView?.textColor = color
            textColor = color
        }
    }
}
