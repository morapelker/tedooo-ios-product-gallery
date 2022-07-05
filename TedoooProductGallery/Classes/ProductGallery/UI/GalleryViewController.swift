//
//  GalleryViewController.swift
//  TedoooProductGallery
//
//  Created by Mor on 05/07/2022.
//

import Foundation
import UIKit
import TedoooProductGalleryApi
import Combine
import TedoooCombine
import ProductProviderApi
import AlignedCollectionViewFlowLayout
import TedoooStyling
import TedoooImagePicker
import Dwifft
import TedoooImageSwiperOfferScreen

class GalleryViewController: UIViewController {
    
    private var viewModel: MainViewModel!
    private var bag = CombineBag()
    
    @Inject private var imagePicker: TedoooImagePicker
    @Inject private var priceSetter: ProductProviderApi
    @Inject private var imageSwiper: ImageSwiperScreen

    
    static func create(id: String, coverPhoto: String?, urls: [String], owned: Bool, shopOwner: TedoooProductGalleryApi.ShopOwner?) -> UIViewController {
        let vc = GPHelper.instantiateViewController(type: GalleryViewController.self)
        vc.viewModel = MainViewModel(
            shopId: id,
            initialCover: coverPhoto,
            products: urls.map({ProductItem(imageUrl: $0, price: 0, currency: "", currencyCode: "", title: nil, description: nil)}),
            owned: owned,
            shopOwner: shopOwner
        )
        vc.modalPresentationStyle = .overCurrentContext
        return vc
    }
    
    static func createFromNotification(linkId: String) -> AnyPublisher<UIViewController, ProductScreenError> {
        return Just(GPHelper.instantiateViewController(type: GalleryViewController.self)).setFailureType(to: ProductScreenError.self).eraseToAnyPublisher()
    }

    private struct ProductShopFullResponse: Decodable {
        let products: [ProductShopResponse]
        let coverPhoto: String?
    }
    
    private struct ProductShopResponse: Decodable {
        let imageUrl: String
        let price: Price
        let title: String?
        let description: String?
        
        enum CodingKeys: String, CodingKey {
            case imageUrl
            case price
            case currency
            case currencyCode
            case title
            case description
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            imageUrl = try container.decode(String.self, forKey: .imageUrl)
            price = Price(
                price: try container.decode(Int.self, forKey: .price),
                currency: try container.decode(String.self, forKey: .currency),
                currencyCode: try container.decode(String.self, forKey: .currencyCode)
            )
            title = try container.decodeIfPresent(String.self, forKey: .title)
            description = try container.decodeIfPresent(String.self, forKey: .description)
        }
        
    }
    
    @objc private func startDragging(_ tap: UILongPressGestureRecognizer) {
        guard let view = tap.view else { return }
        switch tap.state {
        case .began:
            guard let selectedIndexPath = self.collectionView.indexPathForItem(at: tap.location(in: self.collectionView)) else { return }
            self.collectionView.beginInteractiveMovementForItem(at: selectedIndexPath)
        case .changed:
            self.collectionView.updateInteractiveMovementTargetPosition(tap.location(in: view))
        case .ended:
            self.collectionView.endInteractiveMovement()
        default:
            self.collectionView.cancelInteractiveMovement()
        }
    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let layout = collectionView.collectionViewLayout as? AlignedCollectionViewFlowLayout {
            layout.horizontalAlignment = .left
        }
        
        let longGesture = UILongPressGestureRecognizer(target: self, action: #selector(startDragging(_:)))
        collectionView.addGestureRecognizer(longGesture)
        
        subscribe()
    }
    
    private var isMoving = false
    
    private func subscribe() {
        viewModel.products.withPrevious().sink { [weak self] (prev, current) in
            guard let self = self, !self.isMoving, let prev = prev else { return }
            let diff = Dwifft.diff(prev, current)
            self.collectionView.performBatchUpdates {
                let imageSection = self.viewModel.showingCoverSection ? 1 : 0
                diff.forEach { diff in
                    switch diff {
                    case .insert(let index, _):
                        self.collectionView.insertItems(at: [IndexPath(row: index, section: imageSection)])
                        break
                    case .delete(let index, _):
                        self.collectionView.deleteItems(at: [IndexPath(row: index, section: imageSection)])
                        break
                    }
                }
            } completion: { _ in
            }
        } => bag
        
    }
    
    private var cellWidth: CGFloat?
    
    private func calculateCellWidth(width: CGFloat) -> CGFloat {
        let x = ceil(width / 250)
        return CGFloat(width / x) - 4 + floor(CGFloat(4 / x))
    }
    
    @IBAction func closeClicked() {
        self.dismiss(animated: true)
    }
}

extension GalleryViewController: UICollectionViewDelegate, UICollectionViewDataSource , UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 && viewModel.showingCoverSection {
            return 1
        }
        return viewModel.products.value.count
    }
    
    @objc private func plusClicked() {
        imagePicker.pickImages(from: self, single: false, withCamera: false, edit: true).sink { [weak self] images in
            if let self = self, !images.isEmpty {
                self.viewModel.uploadImages(images)
            }
        } => bag
    }
    
    @objc private func editImage(_ tap: UITapGestureRecognizer) {
        guard let indexPath = collectionView.indexPathForItem(at: tap.location(in: self.collectionView)) else { return }
        guard viewModel.owned.value && indexPath.section == 1 && indexPath.row != 0 else { return }
        let item = viewModel.products.value[indexPath.row]
        if item.loading {
            return
        }
        guard let cell = collectionView.cellForItem(at: indexPath) as? ImageGridPriceCell, let image = cell.mainImage.image else { return }
        imagePicker.editImage(from: self, image: image).sink { [weak self] img in
            guard let self = self else { return }
            self.viewModel.editImage(index: indexPath.row, toImage: img)
        } => bag
    }
    
    func collectionView(_ collectionView: UICollectionView, targetIndexPathForMoveOfItemFromOriginalIndexPath originalIndexPath: IndexPath, atCurrentIndexPath currentIndexPath: IndexPath, toProposedIndexPath proposedIndexPath: IndexPath) -> IndexPath {
        if proposedIndexPath.section != 1 {
            return IndexPath(row: 1, section: 1)
        }
        if proposedIndexPath.row == 0 {
            return IndexPath(row: 1, section: 1)
        }
        return proposedIndexPath
    }
    
    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        return indexPath.row != 0 && indexPath.section == 1
    }
    
    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        isMoving = true
        viewModel.move(sourceIndexPath.row, destinationIndexPath.row)
        isMoving = false
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 4
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 4
    }
    
    @objc private func deleteClicked(_ tap: UITapGestureRecognizer) {
        guard let indexPath = collectionView.indexPathForItem(at: tap.location(in: self.collectionView)) else { return }
        let alert = UIAlertController(title: NSLocalizedString("Remove product?", comment: ""), message: NSLocalizedString("Are you sure you want to remove this product?", comment: ""), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Remove", comment: ""), style: .destructive, handler: { _ in
            self.viewModel.removeImage(indexPath.row)
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        self.present(alert, animated: true)
    }
    
    @objc private func deleteCoverPhoto() {
        let alert = UIAlertController(title: NSLocalizedString("Remove cover photo?", comment: ""), message: NSLocalizedString("Are you sure you want to remove your cover photo?", comment: ""), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Remove", comment: ""), style: .destructive, handler: { _ in
            self.viewModel.deleteCoverPhoto()
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        self.present(alert, animated: true)
    }
    
    @objc private func editCoverPhoto() {
        guard let cell = collectionView.cellForItem(at: IndexPath(row: 0, section: 0)) as? CoverCell, let imageView = cell.mainImage, let image = imageView.image else { return }
        imagePicker.editImage(from: self, image: image).sink { [weak self] newImage in
            self?.viewModel.uploadCoverPhoto(newImage)
        } => bag
    }
    
    @objc private func uploadCoverPhoto() {
        imagePicker.pickImages(from: self, single: true, withCamera: true, edit: true).sink { [weak self] image in
            guard let image = image.first else { return }
            self?.viewModel.uploadCoverPhoto(image)
        } => bag
    }
    
    @objc private func changePrice(_ tap: UITapGestureRecognizer) {
        guard let indexPath = collectionView.indexPathForItem(at: tap.location(in: collectionView))?.row else { return }
        let item = viewModel.products.value[indexPath]
        guard let url = item.url else { return }
        priceSetter.launchEditPriceFlow(from: self, product: ProductItem(imageUrl: url, price: item.price, currency: item.currency, currencyCode: item.currencyCode, title: item.title, description: item.description)).sink { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .cancelled(let vc):
                vc.dismiss(animated: true)
            case .changed(let vc, model: let updates):
                vc.dismiss(animated: true)
                self.viewModel.productUpdated(at: indexPath, updates: updates)
            }
        } => bag
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.row == 0 && indexPath.section == 0 && viewModel.showingCoverSection {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "coverCell", for: indexPath) as! CoverCell
            viewModel.coverPhoto.combineLatest(viewModel.owned).sink { [weak cell] (coverPhoto, owned) in
                guard let cell = cell else { return }
                if let coverPhoto = coverPhoto {
                    if let image = coverPhoto.image {
                        cell.mainImage.image = image
                    } else if let url = coverPhoto.url, let url = URL(string: url) {
                        cell.mainImage.kf.setImage(with: url)
                    }
                    if owned {
                        cell.viewDelete.isHidden = false
                        cell.viewEdit.isHidden = false
                    } else {
                        cell.viewDelete.isHidden = true
                        cell.viewEdit.isHidden = true
                    }
                    cell.imgMid.isHidden = true
                    if coverPhoto.loading {
                        cell.spinner.startAnimating()
                        cell.mainImage.alpha = 0.2
                    } else {
                        cell.spinner.stopAnimating()
                        cell.mainImage.alpha = 1.0
                    }
                } else {
                    cell.mainImage.image = nil
                    cell.viewDelete.isHidden = true
                    cell.viewEdit.isHidden = true
                    cell.imgMid.isHidden = false
                }
            } => cell.bag
            
            cell.addGestureRecognizer(target: self, selector: #selector(uploadCoverPhoto), shouldClear: true)
            cell.viewDelete.addGestureRecognizer(target: self, selector: #selector(deleteCoverPhoto), shouldClear: true)
            cell.viewEdit.addGestureRecognizer(target: self, selector: #selector(editCoverPhoto), shouldClear: true)
            
            return cell
        }
        let item = viewModel.products.value[indexPath.row]
        if item.id == "plus" {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "plusCell", for: indexPath) as! PlusGridCell
            cell.addGestureRecognizer(target: self, selector: #selector(plusClicked), shouldClear: true)
            return cell
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cellId", for: indexPath) as! ImageGridPriceCell
        cell.mainImage.addGestureRecognizer(target: self, selector: #selector(enlargeImage(_:)), shouldClear: true)
        if viewModel.owned.value {
            cell.btnEdit.isHidden = false
            cell.viewDelete.isHidden = false
            cell.viewPrice.isHidden = false
            cell.btnEdit.addGestureRecognizer(target: self, selector: #selector(editImage(_:)), shouldClear: true)
            cell.viewDelete.addGestureRecognizer(target: self, selector: #selector(deleteClicked), shouldClear: true)
            if item.price == 0 {
                cell.lblPrice.text = NSLocalizedString("Add Price", comment: "")
            } else if let title = item.title, let description = item.description, !title.isEmpty && !description.isEmpty {
                cell.lblPrice.text = item.toFormattedPrice()
            } else {
                cell.lblPrice.text = NSLocalizedString("Add Details", comment: "")
            }
            cell.viewPrice.addGestureRecognizer(target: self, selector: #selector(changePrice(_:)), shouldClear: true)
        } else {
            cell.btnEdit.isHidden = true
            cell.viewDelete.isHidden = true
            cell.viewPrice.clearGestureRecognizers()
            if item.price != 0 {
                cell.viewPrice.isHidden = false
                cell.lblPrice.text = item.toFormattedPrice()
            } else {
                cell.viewPrice.isHidden = true
            }
        }
        if let image = item.image {
            cell.mainImage.image = image
        } else if let url = item.url, let url = URL(string: url) {
            cell.mainImage.kf.setImage(with: url)
        }
        if item.loading {
            cell.mainImage.alpha = 0.2
            cell.spinner.startAnimating()
        } else {
            cell.spinner.stopAnimating()
            cell.mainImage.alpha = 1.0
        }
        return cell
    }
    
    

    @objc private func enlargeImage(_ tap: UITapGestureRecognizer) {
        guard let sourceView = tap.view as? UIImageView, let indexPath = self.collectionView.indexPathForItem(at: tap.location(in: self.collectionView)) else { return }
        enlargeImageAtIndex(indexPath.row, sourceView: sourceView, animated: true)
    }
    
    
    private func enlargeImageAtIndex(_ index: Int, sourceView: UIImageView?, animated: Bool) {
        guard let shopId = viewModel.shopId else { return }
        let shopUser: TedoooImageSwiperOfferScreen.ShopOwner?
        if let owner = viewModel.shopOwner {
            shopUser = TedoooImageSwiperOfferScreen.ShopOwner(id: owner.id, username: owner.username, avatar: owner.avatar)
        } else {
            shopUser = nil
        }
        let urls = viewModel.products.value.compactMap({$0.url}).compactMap({URL(string: $0)})
        imageSwiper.launch(in: self, images: urls, prices: viewModel.products.value.map({
            ProductItem(imageUrl: $0.url ?? "", price: 0, currency: "", currencyCode: "", title: nil, description: nil)
        }), currentIndex: index, transitionFrom: sourceView,
                           owned: viewModel.owned.value, shopUser: shopUser, shopId: shopId).sink { [weak self] (vc, scrolled) in
            guard let self = self else { return }
            let imageSection = self.viewModel.showingCoverSection ? 1 : 0
            if let cell = self.collectionView.cellForItem(at: IndexPath(row: index, section: imageSection)) as? ImageGridPriceCell {
                vc.setSourceView(newSource: cell.mainImage)
            }
            self.collectionView.scrollToItem(at: IndexPath(row: index, section: imageSection), at: .top, animated: false)
        } => bag
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if viewModel.owned.value {
            return .init(width: collectionView.frame.width, height: 60)
        }
        return .zero
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionView.elementKindSectionHeader:
            let headerView = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: "headerId",
                for: indexPath) as! SectionTitleCell
            headerView.lblTitle.text = indexPath.section == 1 || !viewModel.showingCoverSection ? NSLocalizedString("Add items", comment: "") : NSLocalizedString("Your cover picture", comment: "")
            return headerView
        default: return UICollectionReusableView()
        }
      
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return .init(top: 8, left: 0, bottom: 0, right: 0)
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return viewModel.showingCoverSection ? 2 : 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if indexPath.section == 0 && viewModel.showingCoverSection {
            return .init(width: collectionView.frame.width, height: 192)
        }
        let width: CGFloat
        if let w = cellWidth {
            width = w
        } else {
            width = calculateCellWidth(width: collectionView.frame.width)
            self.cellWidth = width
        }
        if indexPath.row == viewModel.products.value.count - 1 && indexPath.row != 0 && viewModel.products.value.count % 2 == 1 {
            return .init(width: collectionView.frame.width, height: width)
        }
        return .init(width: width, height: width)
    }
    
    
}

/**
 
 override func viewDidLoad() {
     
     if self.prices.isEmpty {
         GPHelperLocal.request("products/shop/\(shopId)", withAuth: true).responseDecodable(of: [ProductItem].self) { [weak self] res in
             guard let self = self else { return }
             switch res.result {
             case .success(let res):
                 for item in res {
                     self.prices[item.imageUrl] = item
                 }
                 self.collectionView.reloadData()
             case .failure:
                 break
             }
         }
     }
    
 }
 */
