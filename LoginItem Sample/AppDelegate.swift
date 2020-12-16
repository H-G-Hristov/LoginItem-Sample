//
//  AppDelegate.swift
//  LoginItem Sample
//
//  Created by zhaoxin on 2020/1/6.
//  Copyright © 2020 zhaoxin. All rights reserved.
//

import AppKit
import Cocoa
import Network
import ServiceManagement
import SystemConfiguration

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var window: NSWindow? = nil
    private let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setAutoStart()
        setupMenubarTray()
        ProcessInfo.processInfo.disableSuddenTermination()
        setupWorkspaceNotifications()
        
        if UserDefaults.shared.bool(forKey: UserDefaults.Key.startFromLauncher.rawValue) {
            UserDefaults.shared.set(false, forKey: UserDefaults.Key.startFromLauncher.rawValue)
        } else {
            showWindow()
        }
    }
    
    @objc private func setAutoStart() {
        let shouldEnable = UserDefaults.standard.bool(forKey: ViewController.autoStart)
        
        if !SMLoginItemSetEnabled("com.parussoft.LoginItem-Sample-Launcher" as CFString, shouldEnable) {
            print("Login Item Was Not Successful")
        }
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

// MARK: - Menubar item

extension AppDelegate {
    
    private func setupMenubarTray() {
        guard let button = statusItem.button else {
            fatalError()
        }
        
        setTrayIcon(for: button)
        button.action = #selector(mouseLeftButtonClicked)
        
        // Add mouse right click
        let subView = MouseRightClickView(frame: button.frame)
        subView.closure = {
            self.constructMenu()
            button.performClick(nil) // menu won't show without this
        }
        button.addSubview(subView)
    }
    
    private func setTrayIcon(for button:NSStatusBarButton) {
        button.image = NSImage(imageLiteralResourceName: "MonochromeIcon")
    }
    
    private func constructMenu() {
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: NSLocalizedString("About", comment: ""), action: #selector(NSApp.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        menu.addItem(withTitle: NSLocalizedString("Quit", comment: ""), action: #selector(quit), keyEquivalent: "")
        statusItem.menu = menu
    }
    
    @objc private func mouseLeftButtonClicked() {
        guard let window = self.window else {
            showWindow()
            return
        }
        
        var operated = false
        
        if NSApp.isHidden {
            unhide()
            if !operated { operated = true }
        }
        
        if window.isMiniaturized {
            window.deminiaturize(nil)
            if !operated { operated = true }
        }
        
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
            if !operated { operated = true }
        }
        
        guard window.isKeyWindow else { return }
        
        if !operated {
            hide()
        }
    }
}

extension AppDelegate: NSMenuDelegate {
    
    // Remove the menu or later mouse left click will call it.
    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }
    
}

// MARK: - NSApp and Window

extension AppDelegate {
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        handleLogoutAsync()
        
        // Delay Poweroff/Restart/Logout
        return .terminateLater
    }
    
    private func showWindow() {
        let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: "mainWindowController") as! NSWindowController
        
        window = windowController.window
        window?.delegate = self
        
        showInDock()
        window!.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        NotificationCenter.default.addObserver(self, selector: #selector(setAutoStart), name: ViewController.autoStartDidChange, object: nil)
    }
    
    private func hide() {
        removeFromDock()
        NSApp.hide(nil)
    }
    
    private func unhide() {
        showInDock()
        NSApp.unhide(nil)
    }
    
    private func showInDock() {
        NSApp.setActivationPolicy(.regular)
    }
    
    private func removeFromDock() {
        NSApp.setActivationPolicy(.accessory)
    }
    
    @objc private func quit() {
        ProcessInfo.processInfo.enableSuddenTermination()
        NSApp.terminate(nil)
    }
}

extension AppDelegate: NSWindowDelegate {
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }
    
}

// MARK: - NSWorkspace

extension AppDelegate {
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func getDesktopDirectory() -> URL {
        let paths = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func getDownloadDirectory() -> URL {
        let paths = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func getTerminationReason() -> String {
        // https://stackoverflow.com/questions/56839403/detect-a-user-logout-on-macos
        let reason = NSAppleEventManager.shared()
            .currentAppleEvent?
            .attributeDescriptor(forKeyword: kAEQuitReason)
        
        switch reason?.enumCodeValue {
        case kAELogOut, kAEReallyLogOut:
            return "logout"
            
        case kAERestart, kAEShowRestartDialog:
            return "restart"
            
        case kAEShutDown, kAEShowShutdownDialog:
            return "shutdown"
            
        case 0:
            // `enumCodeValue` docs:
            //
            //    The contents of the descriptor, as an enumeration type,
            //    or 0 if an error occurs.
            return "unknown error"
            
        default:
            return "Cmd + Q, Quit menu item, ..."
        }
    }
    
    func handleLogoutAsync() {
        // Must delay this operation or the main menu will leave a selected state when the app shows next time.
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            [weak self] in
            
            guard let directory = self?.getDownloadDirectory().appendingPathComponent("LoginItem") else {
                return
            }
            
            guard let isOk = self?.makeSaveToDirectory(for: directory), isOk else {
                return
            }
            
            let dateFormatter = DateFormatter()
            //  dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let currentDateTime = Date()
            let dateTimeStr = dateFormatter.string(from: currentDateTime)
            let dateTimeFileStr = dateTimeStr
                .replacingOccurrences(of: " ", with: "_T")
                .replacingOccurrences(of: ":", with: "-")
            
            let filename = directory.appendingPathComponent("LoginItem-\(dateTimeFileStr).txt")
            
            var logStr =
                """
                    Logout/Shutdown/Restart event at: \(dateTimeStr)
                    Event type:                       \(self?.getTerminationReason() ?? "nil")\n
                """
            logStr.append(self?.checkNetworkReachability() ?? "")
            do {
                try logStr.write(to: filename, atomically: true, encoding: String.Encoding.utf8)
            }
            catch {
                // failed to write file – bad permissions, bad filename, missing permissions, or more likely it can't be converted to the encoding
            }
            
            self?.hide()
            
            // Continue Poweroff/Restart/Logout
            NSApplication.shared.reply(toApplicationShouldTerminate: true)
        }
    }
    
    func checkNetworkReachability(with hostName: String? = nil) -> String {
        // Used method:
        //   https://marcosantadev.com/network-reachability-swift/
        // Other methods:
        //   https://www.hackingwithswift.com/example-code/networking/how-to-check-for-internet-connectivity-using-nwpathmonitor
        //   https://stackoverflow.com/questions/1083701/how-to-check-for-an-active-internet-connection-on-ios-or-macos
        
        let reachability: SCNetworkReachability?
        
        // Obtain reachability by host name
        if let hostName = hostName {
            reachability = SCNetworkReachabilityCreateWithName(nil, hostName)
        }
        // btain reachability by a network address reference
        else {
            // Initializes the socket IPv4 address struct
            var address = sockaddr_in()
            address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            address.sin_family = sa_family_t(AF_INET)
            
            // Passes the reference of the struct
            reachability = withUnsafePointer(to: &address, { pointer in
                // Converts to a generic socket address
                return pointer.withMemoryRebound(to: sockaddr.self, capacity: MemoryLayout<sockaddr>.size) {
                    // $0 is the pointer to `sockaddr`
                    return SCNetworkReachabilityCreateWithAddress(nil, $0)
                }
            })
        }
        
        var reachabilityFlags = SCNetworkReachabilityFlags()
        var areFlagsOk = false
        
        if let reachability = reachability {
            areFlagsOk = SCNetworkReachabilityGetFlags(reachability, &reachabilityFlags)
        }
        
        return
            """
                Network reachability flags state: \(areFlagsOk ? "OK" : "unavailable")
                Network is reachable:             \(isNetworkReachable(with: reachabilityFlags) )
            """
    }
    
    func isNetworkReachable(with flags: SCNetworkReachabilityFlags) -> Bool {
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        let canConnectAutomatically = flags.contains(.connectionOnDemand) || flags.contains(.connectionOnTraffic)
        let canConnectWithoutUserInteraction = canConnectAutomatically && !flags.contains(.interventionRequired)
        
        return isReachable
            && (!needsConnection || canConnectWithoutUserInteraction)
    }
    
    func makeSaveToDirectory(for url: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil)
        }
        catch {
            print(error)
            
            return false
        }
        
        return true
    }
    
    private func setupWorkspaceNotifications() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(didWake(_:)), name: NSWorkspace.didWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(willSleep(_:)), name: NSWorkspace.willSleepNotification, object: nil)
        center.addObserver(self, selector: #selector(willPowerOff(_:)), name: NSWorkspace.willPowerOffNotification, object: nil)
    }
    
    @objc private func didWake(_ noti:Notification) {
        ProcessInfo.processInfo.disableSuddenTermination()
    }
    
    @objc private func willSleep(_ noti:Notification) {
        ProcessInfo.processInfo.enableSuddenTermination()
    }
    
    @objc private func willPowerOff(_ noti:Notification) {
        quit()
    }
    
}
