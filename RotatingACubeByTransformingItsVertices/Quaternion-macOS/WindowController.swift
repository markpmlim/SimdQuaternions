//
//  WindowController.swift
//  Quaternion-macOS
//
//  Created by Mark Lim Pak Mun on 13/11/2018.
//  Copyright © 2018 Mark Lim Pak Mun. All rights reserved.
//

import Cocoa
import AppKit

class WindowController: NSWindowController {
    var viewController: ViewController!
    @IBOutlet var toolbar: PlatformToolbar!
    @IBOutlet var playStopButton: NSToolbarItem!

    override func windowDidLoad() {
        super.windowDidLoad()
        self.viewController = self.window?.contentViewController as? ViewController
        // The window?.contentViewController could be downcast to an instance of NSTabViewController
        // provided it was not downcasted to an instance of ViewController
   }

    @IBAction func segmentedControlHandler(_ sender: Any) {
        let segmentedControl = sender as! NSSegmentedControl
        viewController!.modeSegmentedControlChangeHandler(segmentedControl: segmentedControl)
    }

    @IBAction func runButtonHandler(_ sender: Any) {
        //let toolbarItem = sender as! NSToolbarItem
        //toolbarItem.label = "Stop"
        //toolbarItem.image = NSImage(named: .stopProgressFreestandingTemplate)
        viewController?.runButtonTouchHandler()
    }
}
