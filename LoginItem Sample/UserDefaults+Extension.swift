//
//  UserDefaults+Extension.swift
//  LoginItem Sample
//
//  Created by zhaoxin on 2020/1/12.
//  Copyright © 2020 zhaoxin. All rights reserved.
//

import Foundation

extension UserDefaults {
    
    public enum Key: String {
        
        case autoLaunchWhenUserLogin
        case startFromLauncher
        
    }
    
    public static let shared = UserDefaults(suiteName: "96NM39SGJ5.group.com.parussoft.LoginItem-Sample.shared")!
    
}
