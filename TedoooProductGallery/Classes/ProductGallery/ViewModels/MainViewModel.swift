//
//  MainViewModel.swift
//  TedoooProductGallery
//
//  Created by Mor on 05/07/2022.
//

import Foundation
import TedoooProductGalleryApi
import ProductProviderApi
import Combine
import TedoooRestApi
import TedoooCombine
import LoginProviderApi

struct ProductItemWithLoading: Equatable {
    
    let id: String
    var image: UIImage?
    var url: String?
    var price: Int
    var currency: String
    var currencyCode: String
    var title: String?
    var description: String?
    var loading: Bool
    
    init(image: UIImage?, url: String? = nil, loading: Bool) {
        self.id = ""
        self.image = image
        self.url = url
        self.price = 0
        self.currency = ""
        self.currencyCode = ""
        self.title = nil
        self.description = nil
        self.loading = loading
    }
    
    init(id: String, image: UIImage?, url: String? = nil, price: Int, currency: String, currencyCode: String, title: String? = nil, description: String? = nil, loading: Bool) {
        self.id = id
        self.image = image
        self.url = url
        self.price = price
        self.currency = currency
        self.currencyCode = currencyCode
        self.title = title
        self.description = description
        self.loading = loading
    }
    
    public func toFormattedPrice() -> String {
        return Price(price: price, currency: currency, currencyCode: currencyCode).toFormattedPrice()
    }
}

class MainViewModel {
    let shopOwner: ShopOwner?
    let coverPhoto: CurrentValueSubject<ProductItemWithLoading?, Never>
    let products: CurrentValueSubject<[ProductItemWithLoading], Never>
    let owned: CurrentValueSubject<Bool, Never>
    let shopId: String
    
    private var bag = CombineBag()
    private var subject: PassthroughSubject<ProductChangeUpdate, Never>?
    
    private let uploadImageRequests = PassthroughSubject<UploadImageRequest, Never>()
    
    @Inject private var awsClient: AwsClient
    @Inject private var loginProvider: LoginProvider
    @Inject private var restApi: RestApiClient
    
    let showingCoverSection: Bool
    
    init(
        shopId: String,
        initialCover: String?,
        products: [ProductItem],
        owned: Bool,
        shopOwner: ShopOwner?,
        subject: PassthroughSubject<ProductChangeUpdate, Never>?
    ) {
        self.subject = subject
        self.shopId = shopId
        if let cover = initialCover {
            self.coverPhoto = CurrentValueSubject(ProductItemWithLoading(image: nil, url: cover, loading: false))
        } else {
            self.coverPhoto = CurrentValueSubject(nil)
        }
        
        self.owned = CurrentValueSubject(owned)
        
        
        if owned {
            self.products = CurrentValueSubject([ProductItemWithLoading(id: "plus", image: nil, price: 0, currency: "", currencyCode: "", loading: false)] + products.map({ product in
                ProductItemWithLoading(id: UUID().uuidString, image: nil, url: product.imageUrl, price: product.price, currency: product.currency, currencyCode: product.currencyCode, loading: false)
            }))
        } else {
            self.products = CurrentValueSubject(products.map({ product in
                ProductItemWithLoading(id: UUID().uuidString, image: nil, url: product.imageUrl, price: product.price, currency: product.currency, currencyCode: product.currencyCode, loading: false)
            }))
        }
        
        self.shopOwner = shopOwner
        if owned {
            showingCoverSection = true
        } else {
            showingCoverSection = initialCover != nil
        }
        uploadImageRequests.buffer(size: 100, prefetch: .keepFull, whenFull: .dropOldest).flatMap(maxPublishers: .max(5)) { image in
            self.awsClient.uploadImage(request: image)
        }.sink { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result.result {
                case .success(let url):
                    self.products.value = self.products.value.map({ item in
                        if item.id == result.id {
                            var i = item
                            i.loading = false
                            i.url = url
                            return i
                        }
                        return item
                    })
                default:break
                }
                self.updateIfNotLoading()
            }
        } => bag
        
        if subject != nil {
            self.products.combineLatest(self.coverPhoto).sink { [weak self] (products, coverPhoto) in
                guard let self = self, let subject = self.subject else { return }
                subject.send(ProductChangeUpdate(coverPhoto: coverPhoto?.url, imageUrls: products.compactMap({$0.url})))
            } => bag
        }
        
        let minCount = self.owned.value ? 1 : 0
        if self.products.value.count > minCount && self.products.value.allSatisfy({$0.price == 0}) {
            
            self.restApi.requestRx(outputType: [ProductItem].self, request: HttpRequest(path: "products/shop/\(shopId)", withAuth: true)).sink { _ in
            } receiveValue: { [weak self] productItems in
                guard let self = self else { return }
                var prices = [String: ProductItem]()
                for item in productItems {
                    prices[item.imageUrl] = item
                }
                self.products.value = self.products.value.map({ it in
                    if let url = it.url, let product = prices[url] {
                        var it = it
                        it.price = product.price
                        it.title = product.title
                        it.description = product.description
                        it.currency = product.currency
                        it.currencyCode = product.currencyCode
                        return it
                    }
                    return it
                })
            } => self.bag
        }
    }
    
    private struct UpdatePriceRequest: Encodable {
        let imageUrl: String
        let price: Price?
        let title: String?
        let description: String?
    }
    
    func productUpdated(at index: Int, updates: ProductUpdateModel) {
        products.value = products.value.enumerated().map({ (offset, item) in
            if offset == index {
                var item = item
                item.title = updates.title
                item.description = updates.description
                if let price = updates.price {
                    item.price = price.price
                    item.currency = price.currency
                    item.currencyCode = price.currencyCode
                } else {
                    item.price = 0
                    item.currency = ""
                    item.currencyCode = ""
                }
                if let url = item.url {
                    self.updateProductServer(url: url, updates: updates)
                }
                return item
            } else {
                return item
            }
        })
    }
    
    private func updateProductServer(url: String, updates: ProductUpdateModel) {
        restApi.requestRx(request: HttpRequest(path: "products/shop/\(shopId)", withAuth: true, method: .patch), parameters: UpdatePriceRequest(imageUrl: url, price: updates.price, title: updates.title, description: updates.description)).sink { _ in
        } receiveValue: { _ in
        } => bag
    }
    
    private struct UpdateImageRequest: Encodable {
        let images: [String]
    }
   
    func updateIfNotLoading() {
        let hasLoading = products.value.contains(where: {$0.loading})
        if !hasLoading {
            updateShop(urls: products.value.compactMap({$0.url}))
        }
    }
    
    private func updateShop(urls: [String]) {
        restApi.requestRx(request: HttpRequest(path: "updateshop/\(shopId)", withAuth: true, method: .patch), parameters: UpdateImageRequest(images: urls)).sink { _ in
            
        } receiveValue: { _ in
        } => bag
    }
    
    func deleteCoverPhoto() {
        coverPhoto.send(nil)
        self.updateCoverPhotoServer()
    }
    
    func uploadCoverPhoto(_ image: UIImage) {
        guard let token = loginProvider.loggedInUserSubject.value?.token else { return }
        coverPhoto.value = ProductItemWithLoading(image: image, loading: true)
        
        awsClient.uploadImage(request: UploadImageRequest(image: image, token: token)).sink { [weak self] response in
            guard let self = self else { return }
            switch response.result {
            case .success(let url):
                self.coverPhoto.value = ProductItemWithLoading(image: image, url: url, loading: false)
                self.updateCoverPhotoServer()
            case .failure:
                self.coverPhoto.value = nil
            case .progress: break
            }
        } => bag
    }
    
    private struct UpdateCoverRequest: Encodable {
        let coverPhoto: String?
    }
    
    private func updateCoverPhotoServer() {
        restApi.requestRx(request: HttpRequest(path: "v2/shops/cover/\(shopId)", withAuth: true, method: .patch), parameters: UpdateCoverRequest(coverPhoto: coverPhoto.value?.url)).sink { _ in
        } receiveValue: { _ in
        } => bag
    }
    
    func editImage(index: Int, toImage: UIImage) {
        guard let token = loginProvider.loggedInUserSubject.value?.token else { return }
        self.products.value = self.products.value.enumerated().map({ (offset, img) in
            if offset == index {
                var img = img
                img.loading = true
                img.image = toImage
                return img
            }
            return img
        })
        awsClient.uploadImage(request: UploadImageRequest(image: toImage, token: token)).sink { [weak self] res in
            guard let self = self else { return }
            switch res.result {
            case .success(let url):
                self.products.value = self.products.value.enumerated().map({ (offset, img) in
                    if offset == index {
                        var img = img
                        img.loading = false
                        img.url = url
                        return img
                    }
                    return img
                })
            case .failure:
                self.products.value = self.products.value.enumerated().map({ (offset, img) in
                    if offset == index {
                        var img = img
                        img.loading = false
                        return img
                    }
                    return img
                })
            case .progress:break
            }
            self.updateIfNotLoading()
        } => bag
    }
    
    func move(_ from: Int, _ to: Int) {
        var current = products.value
        if from != to, current.count > from {
            let fromImage = current[from]
            current.remove(at: from)
            current.insert(fromImage, at: to)
            products.send(current)
            self.updateIfNotLoading()
        }
    }
    
    func uploadImages(_ images: [UIImage]) {
        guard let token = loginProvider.loggedInUserSubject.value?.token else { return }

        let ids = images.map({_ in UUID().uuidString})
        
        for (offset, image) in images.enumerated() {
            uploadImageRequests.send(UploadImageRequest(id: ids[offset], image: image, token: token))
        }
        var newImages = self.products.value
        newImages.insert(contentsOf: images.enumerated().map({ (offset, img) in
            ProductItemWithLoading(id: ids[offset], image: img, price: 0, currency: "", currencyCode: "", loading: true)
        }), at: 1)
        self.products.value = newImages
    }
    
    func removeImage(_ index: Int) {
        var cur = self.products.value
        cur.remove(at: index)
        self.products.value = cur
        self.updateIfNotLoading()
    }
    
}
