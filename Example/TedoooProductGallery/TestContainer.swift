//
//  TestContainer.swift
//  TedoooProductGallery_Example
//
//  Created by Mor on 05/07/2022.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import Foundation
import Swinject
import TedoooProductGallery
import TedoooImagePicker
import TedoooRestApi
import LoginProviderApi
import ProductProviderApi
import TedoooImageSwiperOfferScreen
import TedoooShopPresentor

class TestContainer {
    static let shared = TestContainer()
    
    private let container = Container()
    let impl: ProductScreenImpl
    
    init() {
        container.register(TedoooImagePicker.self) { _ in
            return Implementors()
        }.inObjectScope(.container)
        container.register(AwsClient.self) { _ in
            return Implementors()
        }.inObjectScope(.container)
        container.register(LoginProvider.self) { _ in
            return Implementors()
        }.inObjectScope(.container)
        container.register(ProductProviderApi.self) { _ in
            return Implementors()
        }.inObjectScope(.container)
        container.register(TedoooRestApi.RestApiClient.self) { _ in
            return Implementors()
        }.inObjectScope(.container)
        container.register(TedoooImageSwiperOfferScreen.ImageSwiperScreen.self) { _ in
            return Implementors()
        }.inObjectScope(.container)
        container.register(TedoooShopPresentor.SpecificShopScreen.self) { _ in
            return Implementors()
        }
        impl = ProductScreenImpl(container: container)
    }
    
}
