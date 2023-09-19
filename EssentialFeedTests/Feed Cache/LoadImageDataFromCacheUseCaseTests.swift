//
//  LoadImageDataFromCacheUseCaseTests.swift
//  EssentialFeedTests
//
//  Created by Sam on 19/09/2023.
//

import Foundation
import XCTest
import EssentialFeed

final class LoadImageDataFromCacheUseCaseTests: XCTestCase {
    func test_init_doesNotMessageStore() {
        let (_, store) = makeSUT()
        
        XCTAssertEqual(store.receivedMessage.isEmpty, true)
    }
    
    func test_loadImageData_requestStoreDataForURL() {
        let url = anyURL()
        let (sut, store) = makeSUT()
        
        _ = sut.loadImageData(from: url) { _ in }
        
        XCTAssertEqual(store.receivedMessage, [.retrieve(dataForURL: url)])
    }
    
    func test_loadImageData_failsOnStoreError() {
        let (sut, store) = makeSUT()
        
        expect(sut, completeWithResult: failed()) {
            store.completion(with: anyNSError())
        }
    }
    
    func test_loadImageDataFromURL_deliversNotFoundErrorOnNotFound() {
        let (sut, store) = makeSUT()
        
        expect(sut, completeWithResult: notFound()) {
            store.completion(with: .none)
        }
    }
    
    func test_loadImageDataFromURL_deliversStoredDataOnFound() {
        let (sut, store) = makeSUT()
        let foundData = anyData()
        
        expect(sut, completeWithResult: .success(foundData)) {
            store.completion(with: foundData)
        }
    }
    
    func test_loadImageDataFromURL_doesNotDeliverResultAfterCancelingTask() {
        let (sut, store) = makeSUT()
        
        var capturedResult = [FeedImageDataLoader.Result]()
        let task = sut.loadImageData(from: anyURL()) { result in
            capturedResult.append(result)
        }
        
        task.cancel()
        
        store.completion(with: anyData())
        store.completion(with: anyNSError())
        store.completion(with: .none)
        
        XCTAssertEqual(capturedResult.isEmpty, true)
    }
    
    func test_loadImageDataFromURL_doesNotDeliverResultAfterInstanceHasBeenDeallocated() {
        let store = FeedStoreSpy()
        var sut: LocalFeedImageDataLoader? = LocalFeedImageDataLoader(store: store)
        
        var capturedResult = [FeedImageDataLoader.Result]()
        _ = sut?.loadImageData(from: anyURL()) { result in
            capturedResult.append(result)
        }
        
        sut = nil
        
        store.completion(with: anyData())
        store.completion(with: anyNSError())
        store.completion(with: .none)
        
        XCTAssertEqual(capturedResult.isEmpty, true)
    }
    
    func test_saveImage_requestsImageDataInsertionForURL() {
        let (sut, store) = makeSUT()
        let url = anyURL()
        let imageData = anyData()
        
        sut.save(imageData, for: url) { _ in }
        
        XCTAssertEqual(store.receivedMessage, [.insert(imageData, for: url)])
    }
    
    //MARK: -Helpers
    
    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (LocalFeedImageDataLoader, FeedStoreSpy) {
        let store = FeedStoreSpy()
        let sut = LocalFeedImageDataLoader(store: store)
        trackForMemoryLeak(sut, file: file, line: line)
        trackForMemoryLeak(store, file: file, line: line)
        
        return (sut, store)
    }
    
    private func failed() -> FeedImageDataStore.Result {
        return .failure(LocalFeedImageDataLoader.Error.failed)
    }
    
    private func notFound() -> FeedImageDataStore.Result {
        return .failure(LocalFeedImageDataLoader.Error.notFound)
    }
    
    private func expect(_ sut: LocalFeedImageDataLoader, completeWithResult expectedResult: FeedImageDataStore.Result, action: () -> Void, file: StaticString = #filePath, line: UInt = #line) {
        let exp = expectation(description: "wait for request")
        
        _ = sut.loadImageData(from: anyURL()) { result in
            switch (result, expectedResult) {
            case let (.failure(error as LocalFeedImageDataLoader.Error), .failure(expectedError as LocalFeedImageDataLoader.Error)):
                XCTAssertEqual(error, expectedError)
            case let (.success(data), .success(expectedData)):
                XCTAssertEqual(data, expectedData)
            default:
                XCTFail("Expected result \(expectedResult) got \(result) instead")
            }
            exp.fulfill()
        }
        
        action()
        
        wait(for: [exp], timeout: 1)
    }
    
    private class FeedStoreSpy: FeedImageDataStore {
        enum Message: Equatable {
            case retrieve(dataForURL: URL)
            case insert(_ data: Data, for: URL)
        }
        
        private var completions = [(FeedImageDataStore.Result) -> Void]()
        private(set) var receivedMessage = [Message]()
        
        func retrieve(dataFroURL url: URL, completion: @escaping (FeedImageDataStore.Result) -> ()) {
            receivedMessage.append(.retrieve(dataForURL: url))
            completions.append(completion)
        }
        
        func insert(_ data: Data, for url: URL, completion: @escaping (InsertionResult) -> ()) {
            receivedMessage.append(.insert(data, for: url))
        }
        
        func completion(with error: Error, at index: Int = 0) {
            completions[index](.failure(error))
        }
        
        func completion(with data: Data?, at index: Int = 0) {
            completions[index](.success(data))
        }
    }
}