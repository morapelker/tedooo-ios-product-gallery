//
//  Cells.swift
//  TedoooProductGallery
//
//  Created by Mor on 05/07/2022.
//

import Foundation
import Kingfisher
import TedoooCombine

class PlusGridCell: UICollectionViewCell {
    
    @IBOutlet weak var borderView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        borderView.layer.cornerRadius = 8
    }
    
}

class SectionTitleCell: UICollectionReusableView {
    
    @IBOutlet weak var lblTitle: UILabel!
    
}

class ImageGridPriceCell: UICollectionViewCell {
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var viewFailure: UIView!
    @IBOutlet weak var lblPrice: UILabel!
    @IBOutlet weak var viewPrice: UIView!
    @IBOutlet weak var mainImage: UIImageView!
    @IBOutlet weak var viewDelete: UIView!
    @IBOutlet weak var btnEdit: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        mainImage.kf.indicatorType = .activity
        viewPrice.layer.cornerRadius = 4
        viewDelete.layer.cornerRadius = 4
        btnEdit.layer.cornerRadius = 4
    }
    
}

class CoverCell: UICollectionViewCell {
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var viewFailure: UIView!
    @IBOutlet weak var viewEdit: UIView!
    @IBOutlet weak var mainImage: UIImageView!
    @IBOutlet weak var viewDelete: UIView!
    @IBOutlet weak var imgMid: UIView!
    
    var bag = CombineBag()
    
    override func prepareForReuse() {
        super.prepareForReuse()
        bag = CombineBag()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        mainImage.kf.indicatorType = .activity
    }
    
}
