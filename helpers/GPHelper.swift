//
//  GPHelper.swift
//  TedoooProductGallery
//
//  Created by Mor on 05/07/2022.
//

import Foundation

import UIKit

class GPHelper {
    
    static let shared = GPHelper()
    
    static func instantiateViewController<T: UIViewController>(type: T.Type) -> T {
        return UIStoryboard(name: "Main", bundle: Bundle(for: GPHelper.self)).instantiateViewController(withIdentifier: String(describing: type)) as! T
    }
}
