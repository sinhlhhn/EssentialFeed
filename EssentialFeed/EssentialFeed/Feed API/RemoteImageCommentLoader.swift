//
//  RemoteImageCommentLoader.swift
//  EssentialFeed
//
//  Created by Sam on 29/09/2023.
//

import Foundation

public final class RemoteImageCommentLoader: FeedLoader {
    private let client: HTTPClient
    private let url: URL
    
    public typealias Result = FeedLoader.Result
    
    public enum Error: Swift.Error {
        case connectivity
        case invalidData
    }
    
    public init(client: HTTPClient, url: URL) {
        self.client = client
        self.url = url
    }
    
    public func load(completion: @escaping (Result) -> Void) {
        client.get(from: url) { [weak self] result in
            guard self != nil else { return }
            
            switch result {
            case let .success((data, response)):
                completion(RemoteImageCommentLoader.map(data, response))
            case .failure:
                completion(.failure(Error.connectivity))
            }
        }
    }
    
    private static func map(_ data: Data, _ response: HTTPURLResponse) -> Result {
        do {
            let items = try ImageCommentsMapper.map(data, response).toModels()
            return .success(items)
        } catch {
            return .failure(error)
        }
    }
}

private extension Array where Element == RemoteFeedLoaderItem {
    func toModels() -> [FeedImage] {
        self.map { FeedImage(id: $0.id, description: $0.description, location: $0.location, url: $0.image) }
    }
}
