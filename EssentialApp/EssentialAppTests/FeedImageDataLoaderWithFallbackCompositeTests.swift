//
//  FeedImageDataLoaderWithFallbackCompositeTests.swift
//  EssentialAppTests
//
//  Created by Sam on 21/09/2023.
//

import XCTest
import EssentialFeed

final class FeedImageDataLoaderWithFallbackComposite: FeedImageDataLoader {
    private let primaryLoader: FeedImageDataLoader
    private let fallbackLoader: FeedImageDataLoader
    
    init(primaryLoader: FeedImageDataLoader, fallbackLoader: FeedImageDataLoader) {
        self.primaryLoader = primaryLoader
        self.fallbackLoader = fallbackLoader
    }
    
    private final class TaskWrapped: FeedImageDataLoaderTask {
        var wrapped: FeedImageDataLoaderTask?
        
        func cancel() {
            wrapped?.cancel()
        }
    }
    
    func loadImageData(from url: URL, completion: @escaping (FeedImageDataLoader.Result) -> ()) -> FeedImageDataLoaderTask {
        let task = TaskWrapped()
        task.wrapped = primaryLoader.loadImageData(from: url) { [weak self] result in
            switch result {
            case .success:
                completion(result)
            case .failure:
                task.wrapped = self?.fallbackLoader.loadImageData(from: url) { _ in }
            }
        }
        return task
    }
}

final class FeedImageDataLoaderWithFallbackCompositeTests: XCTestCase {
    func test_init_doesNotLoadImageData() {
        let (_, primaryLoader, fallbackLoader) = makeSUT()
        
        XCTAssertEqual(primaryLoader.requestedURLs.isEmpty, true)
        XCTAssertEqual(fallbackLoader.requestedURLs.isEmpty, true)
    }
    
    func test_loadImageData_loadsFromPrimaryLoaderFirst() {
        let url = anyURL()
        let (sut, primaryLoader, fallbackLoader) = makeSUT()
        
        _ = sut.loadImageData(from: url) { _ in }
        
        XCTAssertEqual(primaryLoader.requestedURLs, [url])
        XCTAssertEqual(fallbackLoader.requestedURLs.isEmpty, true)
    }
    
    func test_loadImageData_loadsFromFallbackLoaderOnPrimaryLoaderFailure() {
        let url = anyURL()
        let (sut, primaryLoader, fallbackLoader) = makeSUT()
        
        _ = sut.loadImageData(from: url) { result in }
        
        primaryLoader.completeLoadImage(with: anyNSError())
        
        XCTAssertEqual(primaryLoader.requestedURLs, [url])
        XCTAssertEqual(fallbackLoader.requestedURLs, [url])
    }
    
    func test_loadImageData_cancelsPrimaryLoaderTaskOnCancel() {
        let url = anyURL()
        let (sut, primaryLoader, fallbackLoader) = makeSUT()
        
        let task = sut.loadImageData(from: url) { result in }
        
        task.cancel()
        
        XCTAssertEqual(primaryLoader.canceledURLs, [url])
        XCTAssertEqual(fallbackLoader.canceledURLs.isEmpty, true)
    }
    
    func test_loadImageData_cancelsFallbackLoaderTaskOnCancelAfterPrimaryLoaderFailure() {
        let url = anyURL()
        let (sut, primaryLoader, fallbackLoader) = makeSUT()
        let task = sut.loadImageData(from: url) { result in }
        
        primaryLoader.completeLoadImage(with: anyNSError())
        task.cancel()
        
        XCTAssertEqual(primaryLoader.canceledURLs.isEmpty, true)
        XCTAssertEqual(fallbackLoader.canceledURLs, [url])
    }
    
    func test_loadImageData_deliversPrimaryDataOnPrimaryLoaderSuccess() {
        let url = anyURL()
        let expectedData = anyData()
        let (sut, primaryLoader, _) = makeSUT()
        
        expect(sut, completeWithResult: .success(expectedData), from: url) {
            primaryLoader.complete(with: expectedData)
        }
    }
    
    //MARK: -Helpers
    
    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (FeedImageDataLoaderWithFallbackComposite, FeedImageDataLoaderSpy, FeedImageDataLoaderSpy) {
        let primaryLoader = FeedImageDataLoaderSpy()
        let fallbackLoader = FeedImageDataLoaderSpy()
        let sut = FeedImageDataLoaderWithFallbackComposite(primaryLoader: primaryLoader, fallbackLoader: fallbackLoader)
        trackForMemoryLeak(sut, file: file, line: line)
        trackForMemoryLeak(fallbackLoader, file: file, line: line)
        trackForMemoryLeak(primaryLoader, file: file, line: line)
        
        return (sut, primaryLoader, fallbackLoader)
    }
    
    private func expect(_ sut: FeedImageDataLoaderWithFallbackComposite, completeWithResult expectedResult: FeedImageDataLoader.Result, from url: URL, action: () -> Void, file: StaticString = #filePath, line: UInt = #line) {
        
        let exp = expectation(description: "wait for load")
        _ = sut.loadImageData(from: url) { result in
            switch (result, expectedResult) {
            case let (.success(receivedData), .success(expectedData)):
                XCTAssertEqual(receivedData, expectedData)
            default:
                XCTFail("Expected \(expectedResult) got \(result) instead")
            }
            exp.fulfill()
        }
        
        action()
        
        wait(for: [exp], timeout: 1)
    }
    
    private func trackForMemoryLeak(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should has been deallocated. Potential memory leak", file: file, line: line)
        }
    }
    
    private func anyURL() -> URL {
        return URL(string: "https://any-url")!
    }
    
    private func anyNSError() -> NSError {
        return NSError(domain: "0", code: 0)
    }
    
    private func anyData() -> Data {
        return Data("any-data".utf8)
    }
    
    private class FeedImageDataLoaderSpy: FeedImageDataLoader {
        private var messages = [(url: URL, completion: (FeedImageDataLoader.Result) -> ())]()
        
        var requestedURLs: [URL] {
            messages.map { $0.url }
        }
        
        var canceledURLs = [URL]()
        
        private final class Task: FeedImageDataLoaderTask {
            let callback: (() -> Void)
            
            init(callback: @escaping () -> Void) {
                self.callback = callback
            }
            
            func cancel() {
                callback()
            }
        }
        
        func loadImageData(from url: URL, completion: @escaping (FeedImageDataLoader.Result) -> ()) -> FeedImageDataLoaderTask {
            messages.append((url, completion))
            return Task { [weak self] in
                self?.canceledURLs.append(url)
            }
        }
        
        func completeLoadImage(with error: Error, at index: Int = 0) {
            messages[index].completion(.failure(error))
        }
        
        func complete(with data: Data, at index: Int = 0) {
            messages[index].completion(.success(data))
        }
    }
}
