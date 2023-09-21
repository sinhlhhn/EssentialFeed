//
//  CoreDataFeedImageDataStoreTests.swift
//  EssentialFeedTests
//
//  Created by Sam on 20/09/2023.
//

import XCTest
import EssentialFeed

final class CoreDataFeedImageDataStoreTests: XCTestCase {
    func test_retrieveImage_deliverImageDataNotFoundErrorOnEmptyData() {
        let sut = makeSUT()
        
        expect(sut, completionWithResult: notFound(), for: anyURL())
    }
    
    func test_retrieveImage_deliverImageDataNotFoundErrorOnStoreDataURLDoesNotMatch() {
        let sut = makeSUT()
        let url = URL(string: "https://a-url")!
        let nonMatchURL = URL(string: "https://a-non-match-url")!
        
        insert(data: anyData(), for: url, into: sut)
        
        expect(sut, completionWithResult: notFound(), for: nonMatchURL)
    }
    
    func test_retrieveImage_deliversFoundDataWhenThereIsAStoredImageDataMatchingURL() {
        let sut = makeSUT()
        let data = anyData()
        let url = anyURL()
        
        insert(data: data, for: url, into: sut)
        
        expect(sut, completionWithResult: found(data), for: url)
    }
    
    func test_retrieveImage_deliversLastInsertedValue() {
        let sut = makeSUT()
        let firstData = anyData()
        let lastData = anyData()
        let url = anyURL()
        
        insert(data: firstData, for: url, into: sut)
        insert(data: lastData, for: url, into: sut)
        
        expect(sut, completionWithResult: found(lastData), for: url)
    }
    
    func test_sideEffects_runSerially() {
        let sut = makeSUT()
        let url = anyURL()
        
        let op1 = expectation(description: "operation 1")
        sut.insert([localFeedImage(url: url)], currentDate: Date()) { _ in
            op1.fulfill()
        }
        
        let op2 = expectation(description: "operation 2")
        sut.insert(anyData(), for: url) { _ in
            op2.fulfill()
        }
        
        let op3 = expectation(description: "operation 3")
        sut.insert(anyData(), for: url) { _ in
            op3.fulfill()
        }
        
        wait(for: [op1, op2, op3], timeout: 5, enforceOrder: true)
    }
    
    //MARK: -Helpers
    
    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> CoreDataFeedStore {
        let storeURL = URL(filePath: "/dev/null")
        let sut = try! CoreDataFeedStore(storeURL: storeURL)
        trackForMemoryLeak(sut, file: file, line: line)
        
        return sut
    }
    
    private func notFound() -> FeedImageDataStore.RetrievalResult {
        return .success(.none)
    }
    
    private func localFeedImage(url: URL) -> LocalFeedImage {
        return LocalFeedImage(id: UUID(), description: nil, location: nil, url: url)
    }
    
    private func found(_ data: Data) -> FeedImageDataStore.RetrievalResult {
        return .success(data)
    }
    
    private func expect(_ sut: CoreDataFeedStore, completionWithResult expectedResult: FeedImageDataStore.RetrievalResult, for url: URL, file: StaticString = #filePath, line: UInt = #line) {
        
        let exp = expectation(description: "Wait for completion")
        sut.retrieve(dataFroURL: url) { receivedResult in
            switch (receivedResult, expectedResult) {
            case let (.success(receivedData), .success(expectedData)):
                XCTAssertEqual(receivedData, expectedData, file: file, line: line)
            default:
                XCTFail("Expected \(expectedResult) got \(receivedResult) instead", file: file, line: line)
            }
            exp.fulfill()
        }
        
        wait(for: [exp] ,timeout: 1)
    }
    
    private func insert(data: Data, for url: URL, into sut: CoreDataFeedStore, file: StaticString = #filePath, line: UInt = #line) {
        let image = localFeedImage(url: url)
        
        let exp = expectation(description: "Wait for completion")
        sut.insert([image], currentDate: Date()) { insertionResult in
            switch insertionResult {
            case .success(()):
                sut.insert(data, for: url) { insertionImageResult in
                    switch insertionImageResult {
                    case .success(()):
                        break
                    default:
                        XCTFail("Expected insert successfully got \(insertionImageResult) instead", file: file, line: line)
                    }
                    exp.fulfill()
                }
            default:
                XCTFail("Expected insert successfully got \(insertionResult) instead", file: file, line: line)
            }
        }
        
        wait(for: [exp], timeout: 1)
    }
}