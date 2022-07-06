//
//  ViewController.swift
//  TedoooProductGallery
//
//  Created by morapelker on 07/05/2022.
//  Copyright (c) 2022 morapelker. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    @IBAction func NoOwnCover(_ sender: Any) {
        let vc = TestContainer.shared.impl.create(id: "id", coverPhoto: "https://cdn.pixabay.com/photo/2013/07/12/17/47/test-pattern-152459_1280.png", urls: [], owned: false, shopOwner: nil, imagesChanged: nil)
        self.present(vc, animated: true)
    }
    
    @IBAction func noOwnNoCover(_ sender: Any) {
        let vc = TestContainer.shared.impl.create(id: "id", coverPhoto: nil, urls: [], owned: false, shopOwner: nil, imagesChanged: nil)
        self.present(vc, animated: true)
    }
    
    @IBAction func ownedCover(_ sender: Any) {
        let vc = TestContainer.shared.impl.create(id: "id", coverPhoto: "https://cdn.pixabay.com/photo/2013/07/12/17/47/test-pattern-152459_1280.png", urls: [], owned: true, shopOwner: nil, imagesChanged: nil)
        self.present(vc, animated: true)
    }
    
    @IBAction func ownedNoCover(_ sender: Any) {
        let vc = TestContainer.shared.impl.create(id: "id", coverPhoto: nil, urls: [], owned: true, shopOwner: nil, imagesChanged: nil)
        self.present(vc, animated: true)
    }
}

