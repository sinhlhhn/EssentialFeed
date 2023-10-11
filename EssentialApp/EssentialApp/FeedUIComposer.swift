//
//  FeedUIComposer.swift
//  EssentialFeediOS
//
//  Created by Sam on 08/09/2023.
//

import Foundation
import UIKit
import Combine
import EssentialFeed
import EssentialFeediOS

public final class FeedUIComposer {
    private init() {}
    
    private typealias FeedPresentationAdapter = LoadResourcePresentationAdapter<[FeedImage], FeedViewAdapter>
    
    public static func feedComposedWith(loader: @escaping () -> AnyPublisher<[FeedImage], Error>, imageLoader: @escaping (URL) -> FeedImageDataLoader.Publisher) -> ListViewController {
        
        let adapterComposer = FeedPresentationAdapter(
            loader: loader)
        
        let feedViewController = FeedUIComposer.makeWith(delegate: adapterComposer, title: FeedPresenter.title)
        
        adapterComposer.loadPresenter = LoadResourcePresenter(
            loadingView: WeakRefVirtualProxy(feedViewController),
            resourceView:
                FeedViewAdapter(
                    controller: feedViewController,
                    loader: imageLoader),
            errorView: WeakRefVirtualProxy(feedViewController),
            mapper: FeedPresenter.map)
        
        return feedViewController
    }
    
    private static func makeWith(delegate: FeedRefreshViewControllerDelegate, title: String) -> ListViewController {
        let bundle = Bundle(for: ListViewController.self)
        let sb = UIStoryboard(name: "Feed", bundle: bundle)
        let feedViewController = sb.instantiateViewController(identifier: "FeedViewController"){ coder in
            ListViewController(coder: coder, delegate: delegate)
        }
        
        feedViewController.title = title
        
        return feedViewController
    }
}
