//
//  AppDelegate.swift
//  LoginItem Sample Launcher
//
//  Created by zhaoxin on 2020/1/6.
//  Copyright © 2020 zhaoxin. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        UserDefaults.shared.set(true, forKey: UserDefaults.Key.startFromLauncher.rawValue)
        
        let pathComponents = Bundle.main.bundleURL.pathComponents
        var pathComponentsToDiscard = 4
        
        #if DEBUG
        pathComponentsToDiscard = isDebuggerAttached ? 0 : 4
        #endif
        
        let mainRange = 0 ..< (pathComponents.count - pathComponentsToDiscard)
        let mainPath = pathComponents[mainRange].joined(separator: "/")
        try! NSWorkspace.shared.launchApplication(at: URL(fileURLWithPath: mainPath, isDirectory: false), options: [], configuration: [:])
        NSApp.terminate(nil)
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
}

extension AppDelegate {
    
    /// Returns true if the current process is being debugged (either running under the debugger or has a debugger attached post facto).
    ///   https://developer.apple.com/library/archive/qa/qa1361/_index.html
    var isDebuggerAttached: Bool {
        var debuggerIsAttached = false
        
        // Initialize mib, which tells sysctl the info we want, in this case
        // we're looking for information about a specific process ID.
        var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var info: kinfo_proc = kinfo_proc()
        var info_size = MemoryLayout<kinfo_proc>.size
        
        let success = name.withUnsafeMutableBytes { (nameBytePtr: UnsafeMutableRawBufferPointer) -> Bool in
            guard let nameBytesBlindMemory = nameBytePtr.bindMemory(to: Int32.self).baseAddress else { return false }
            // Call sysctl.
            return -1 != sysctl(nameBytesBlindMemory, 4, &info/*UnsafeMutableRawPointer!*/, &info_size/*UnsafeMutablePointer<Int>!*/, nil, 0)
        }
        
        // The original HockeyApp code checks for this; you could just as well remove these lines:
        if !success {
            debuggerIsAttached = false
        }
        
        // We're being debugged if the P_TRACED flag is set.
        if !debuggerIsAttached && (info.kp_proc.p_flag & P_TRACED) != 0 {
            debuggerIsAttached = true
        }
        
        return debuggerIsAttached
    }
    
}

