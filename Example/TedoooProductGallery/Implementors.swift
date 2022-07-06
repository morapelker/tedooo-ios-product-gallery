//
//  Implementors.swift
//  TedoooProductGallery_Example
//
//  Created by Mor on 05/07/2022.
//  Copyright © 2022 CocoaPods. All rights reserved.
//

import Foundation
import TedoooImagePicker
import Combine
import TedoooRestApi
import LoginProviderApi
import ProductProviderApi
import TedoooImageSwiperOfferScreen
import TedoooShopPresentor

class TestSourceScreen: SourceViewScreen {
    func setSourceView(newSource: UIImageView?) {
        print("set new source", newSource)
    }
}

class Implementors: TedoooImagePicker, AwsClient, LoginProvider, ProductProviderApi, RestApiClient, TedoooImageSwiperOfferScreen.ImageSwiperScreen, TedoooShopPresentor.SpecificShopScreen {
    
    func instantiate(id: String) -> UIViewController {
        return UIViewController()
    }
    
    func instantiate(id: String, image: String) -> UIViewController {
        return UIViewController()
    }
    
    func launch(in vc: UIViewController, images: [URL], prices: [ProductItem?], currentIndex: Int, transitionFrom: UIImageView?, owned: Bool, shopUser: ShopOwner?, shopId: String) -> AnyPublisher<(SourceViewScreen, Int), Never> {
        return Just((TestSourceScreen(), 0)).eraseToAnyPublisher()
    }
    
    func requestRx<T, V>(outputType: V.Type, request: HttpRequest, parameters: T) -> AnyPublisher<V, RestException> where T : Encodable, V : Decodable {
        let json = String(data: try! JSONEncoder().encode(parameters), encoding: .utf8)!
        
        print("requesting", request, json)
        return Fail(error: RestException.invalidStatusCode(403, "error", 0)).delay(for: 1.0, scheduler: DispatchQueue.main).eraseToAnyPublisher()
    }
    
    func requestRx<T>(outputType: T.Type, request: HttpRequest) -> AnyPublisher<T, RestException> where T : Decodable {
        print("requesting", request)
        return Fail(error: RestException.invalidStatusCode(403, "error", 0)).delay(for: 1.0, scheduler: DispatchQueue.main).eraseToAnyPublisher()
    }
    
    func requestRx<T>(request: HttpRequest, parameters: T) -> AnyPublisher<Any?, RestException> where T : Encodable {
        let json = String(data: try! JSONEncoder().encode(parameters), encoding: .utf8)!
        print("requesting", request, json)

        return Fail(error: RestException.invalidStatusCode(403, "error", 0)).delay(for: 1.0, scheduler: DispatchQueue.main).eraseToAnyPublisher()
    }
    
    func requestRx(request: HttpRequest) -> AnyPublisher<Any?, RestException> {
        print("requesting", request)
        return Fail(error: RestException.invalidStatusCode(403, "error", 0)).delay(for: 1.0, scheduler: DispatchQueue.main).eraseToAnyPublisher()
    }
    
    var loggedInUserSubject: CurrentValueSubject<LoggedInUser?, Never> {
        CurrentValueSubject(LoggedInUser(id: "some id", name: "some name", avatar: nil, token: "token"))
    }
    
    func launchEditPriceFlow(from: UIViewController, product: ProductItem) -> AnyPublisher<EditProductDetailsResult, Never> {
        return Just(EditProductDetailsResult.changed(UIViewController(), model: .init(price: Price(price: 10, currency: "$", currencyCode: "USD"), title: "some title", description: "description"))).eraseToAnyPublisher()
    }
    
    func pickImages(from: UIViewController, single: Bool, withCamera: Bool, edit: Bool) -> AnyPublisher<[UIImage], Never> {
        print("pick images")
        if single {
            return Just([UIImage(systemName: "xmark")!]).eraseToAnyPublisher()
        }
        return Just([
            UIImage(systemName: "xmark")!,
            UIImage(systemName: "pencil")!,
            UIImage(systemName: "octagon")!,
            UIImage(systemName: "globe")!,
        ]).eraseToAnyPublisher()
    }
    
    func editImage(from: UIViewController, image: UIImage) -> AnyPublisher<UIImage, Never> {
        return Just(UIImage(systemName: "pencil")!).eraseToAnyPublisher()
    }
    
    func uploadImage(request: UploadImageRequest) -> AnyPublisher<UploadImageResponse, Never> {
        let progress = PassthroughSubject<UploadImageResponse, Never>()
        DispatchQueue.main.async {
            progress.send(UploadImageResponse(id: request.id, result: .progress(0.0)))
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.5...2.0)) {
                progress.send(UploadImageResponse(id: request.id, result: .success("https://upload.wikimedia.org/wikipedia/en/9/95/Test_image.jpg")))
                progress.send(completion: .finished)
            }
        }
        return progress.eraseToAnyPublisher()
    }
    
    
}
