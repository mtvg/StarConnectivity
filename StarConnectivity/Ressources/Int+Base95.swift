//
//  Int+Base95.swift
//  Click
//
//  Created by Mathieu Vignau on 10/20/16.
//  Copyright © 2016 RED. All rights reserved.
//

import Foundation

extension String {
    
    subscript (i: Int) -> Character {
        return self[self.index(self.startIndex, offsetBy: i)]
    }
    
    subscript (i: Int) -> String {
        return String(self[i] as Character)
    }
}

extension Int {
    func toBase95() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789~!@#$%^&*()_+=-,./<>?:;[]{}|\\'\"` "
        let radix = chars.characters.count
        var out = ""
        var q = self
        var r = 0
        while true {
            r=q%radix
            out = chars[r] + out
            q=(q-r)/radix
            if q == 0 {
                break
            }
        }
        return out
    }
}
