//
//  Inject.swift
//  TedoooProductGallery
//
//  Created by Mor on 05/07/2022.
//

import Foundation

@propertyWrapper
struct Inject<Component> {
    public let wrappedValue: Component
    public init() {
        self.wrappedValue = DIContainer.shared.resolve(Component.self)
    }
}
