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
import TedoooRestApi
import LoginProviderApi
import ProductProviderApi
import TedoooShopPresentor

public class ProductScreenImpl: ProductGalleryScreen {
    
    @Inject private var restApi: RestApiClient
    @Inject private var loginProvider: LoginProvider
    @Inject private var specificShopProvider: SpecificShopScreen
    
    
    
    private struct ProductOwner: Decodable {
        let id: String
        let username: String
        let avatar: String?
    }
    
    private struct ProductNotificationInformation: Decodable {
        let shopId: String
        let items: [ProductItem]
        let index: Int
        let owner: ProductOwner
        let coverPhoto: String?
    }
    
    public func createFromNotification(in vc: UINavigationController, linkId: String) -> AnyPublisher<Any?, ProductScreenError> {
        let currentId = loginProvider.loggedInUserSubject.value?.id
        return restApi.requestRx(outputType: ProductNotificationInformation.self, request: HttpRequest(path: "products/link/\(linkId)", token: nil)).map { res -> Any? in
            let v = GalleryViewController.create(id: res.shopId, coverPhoto: res.coverPhoto, urls: res.items.map({$0.imageUrl}), owned: res.owner.id == currentId, shopOwner: ShopOwner(id: res.owner.id, username: res.owner.username, avatar: res.owner.avatar), imagesChanged: nil)
            vc.present(v, animated: false) {
                v.scroll(to: res.index)
                v.enlargeImageAtIndex(res.index, sourceView: nil, animated: false)
                let specificShopVc = self.specificShopProvider.instantiate(id: res.shopId)
                vc.pushViewController(specificShopVc, animated: false)
            }
            return nil
        }.mapError({ _ in .invalidLink}).eraseToAnyPublisher()
    }
    
    
    public init(container: Container) {
        DIContainer.shared.register(container: container)
    }
    
    public func create(id: String, coverPhoto: String?, urls: [String], owned: Bool, shopOwner: ShopOwner?, imagesChanged: PassthroughSubject<ProductChangeUpdate, Never>?) -> UIViewController {
        return GalleryViewController.create(id: id, coverPhoto: coverPhoto, urls: urls, owned: owned, shopOwner: shopOwner, imagesChanged: imagesChanged)
    }
}
