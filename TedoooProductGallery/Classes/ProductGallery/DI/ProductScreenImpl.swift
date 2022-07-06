//
//  ProductScreenImpl.swift
//  TedoooProductGallery
//
//  Created by Mor on 05/07/2022.
//

import Foundation
import TedoooProductGalleryApi
import Swinject
import Combine

public class ProductScreenImpl: ProductGalleryScreen {
    
    public init(container: Container) {
        DIContainer.shared.register(container: container)
    }
    
    public func create(id: String, coverPhoto: String?, urls: [String], owned: Bool, shopOwner: ShopOwner?, imagesChanged: PassthroughSubject<ProductChangeUpdate, Never>?) -> UIViewController {
        return GalleryViewController.create(id: id, coverPhoto: coverPhoto, urls: urls, owned: owned, shopOwner: shopOwner, imagesChanged: imagesChanged)
    }
    
    public func createFromNotification(linkId: String) -> AnyPublisher<UIViewController, ProductScreenError> {
        return GalleryViewController.createFromNotification(linkId: linkId)
    }
}
