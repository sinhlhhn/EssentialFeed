//
//  WeakRefVirtualProxy.swift
//  EssentialFeediOS
//
//  Created by Sam on 13/09/2023.
//

import Foundation

class WeakRefVirtualProxy<T: AnyObject> {
    private weak var object: T?
    
    init(_ weakRef: T) {
        self.object = weakRef
    }
}

extension WeakRefVirtualProxy: FeedLoadingView where T: FeedLoadingView {
    func display(_ viewModel: FeedLoadingViewModel) {
        object?.display(viewModel)
    }
}

extension WeakRefVirtualProxy: FeedImageView where T: FeedImageView {
    typealias Image = T.Image
    
    func display(_ viewModel: FeedImageViewModel<T.Image>) {
        object?.display(viewModel)
    }
}
