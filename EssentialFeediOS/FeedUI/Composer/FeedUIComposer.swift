//
//  FeedUIComposer.swift
//  EssentialFeediOS
//
//  Created by Sam on 08/09/2023.
//

import Foundation
import UIKit
import EssentialFeed

public final class FeedUIComposer {
    private init() {}
    
    public static func feedComposedWith(loader: FeedLoader, imageLoader: FeedImageDataLoader) -> FeedViewController {
        let presenter = FeedPresenter(feedLoader: loader)
        let refreshController = FeedRefreshViewController(presenter: presenter)
        
        let feedViewController = FeedViewController(refreshController: refreshController)
        
        presenter.feedLoading = refreshController
        presenter.feedView = FeedViewAdapter(controller: feedViewController, loader: imageLoader)
        
        return feedViewController
    }
    
    private static func adaptFeedToCellController(forwardingTo controller: FeedViewController, loader: FeedImageDataLoader) -> (([FeedImage]) -> ()) {
        return { [weak controller] images in
            controller?.tableModel = images.map { FeedImageCellController(viewModel: FeedImageViewModel(model: $0, imageLoader: loader, imageTransfer: UIImage.init))}
        }
    }
}

private class FeedViewAdapter: FeedView {
    private weak var controller: FeedViewController?
    private let loader: FeedImageDataLoader
    
    init(controller: FeedViewController, loader: FeedImageDataLoader) {
        self.controller = controller
        self.loader = loader
    }
    
    func display(feed: [FeedImage]) {
        controller?.tableModel = feed.map { FeedImageCellController(viewModel: FeedImageViewModel(model: $0, imageLoader: loader, imageTransfer: UIImage.init))}
    }
}
