//
//  GalleryDiContainer.swift
//  TedoooProductGallery
//
//  Created by Mor on 05/07/2022.
//

import Foundation
import Swinject

class DIContainer {
    
    static let shared = DIContainer()
    private var container: Container!
    
    func register(container: Container) {
        self.container = container
    }
    
    func resolve<T>(_ type: T.Type) -> T {
        container.resolve(T.self)!
    }
    
}
