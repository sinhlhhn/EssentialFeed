//
//  RemoteFeedImageDataLoaderTests.swift
//  EssentialFeedTests
//
//  Created by Sam on 15/09/2023.
//

import Foundation
import XCTest
import EssentialFeed

final class RemoteFeedImageDataLoader {
    let client: HTTPClient
    
    init(client: HTTPClient) {
        self.client = client
    }
    
    enum Error: Swift.Error {
        case invalidData
    }
    
    func loadImageData(from url: URL, completion: @escaping (HTTPClient.Result) -> ()) {
        client.get(from: url) { [weak self] result in
            guard self != nil else { return }
            switch result {
            case let .failure(error):
                completion(.failure(error))
            case let .success((data, response)):
                if response.statusCode == 200, !data.isEmpty {
                    completion(.success((data, response)))
                } else {
                    completion(.failure(Error.invalidData))
                }
                break
            }
        }
    }
}

final class RemoteFeedImageDataLoaderTests: XCTestCase {
    func test_init_doesNotPerformAnyRequest() {
        let (_, client) = makeSUT()
        
        XCTAssertTrue(client.capturedURLs.isEmpty)
    }
    
    func test_loadImageDataFromURL_performURLRequest() {
        let url = anyURL()
        let (sut, client) = makeSUT()
        
        let _ = sut.loadImageData(from: url) { _ in }
        
        XCTAssertEqual(client.capturedURLs, [url])
    }
    
    func test_loadImageDataFromURL_performURLRequestTwice() {
        let url = anyURL()
        let (sut, client) = makeSUT()
        
        sut.loadImageData(from: url) { _ in }
        sut.loadImageData(from: url) { _ in }
        
        XCTAssertEqual(client.capturedURLs, [url, url])
    }
    
    func test_loadImageDataFromURL_deliversErrorOnClientError() {
        let clientError = NSError(domain: "a client error", code: 1)
        let (sut, client) = makeSUT()
        
        expect(sut, completionWithResult: .failure(clientError)) {
            client.completeLoadingImage(with: clientError, at: 0)
        }
    }
    
    func test_loadImageDataFromURL_deliversInvalidDataErrorOnNon200HTTPResponse() {
        let (sut, client) = makeSUT()
        
        let samples = [100, 199, 201, 300]
        
        samples.enumerated().forEach { index, statusCode in
            expect(sut, completionWithResult: failure(.invalidData)) {
                client.completeLoadingImage(withStatusCode: statusCode, data: anyData(), at: index)
            }
        }
    }
    
    func test_loadImageDataFromURL_deliversInvalidDataErrorOnEmptyData() {
        let emptyData = Data()
        let (sut, client) = makeSUT()
        
        expect(sut, completionWithResult: failure(.invalidData)) {
            client.completeLoadingImage(withStatusCode: 200, data: emptyData, at: 0)
        }
    }
    
    func test_loadImageDataFromURL_deliversNonEmptyReceivedDataOn200HTTPResponse() {
        let (sut, client) = makeSUT()
        let data = anyData()
        let response = HTTPURLResponse(url: anyURL(), statusCode: 200, httpVersion: nil, headerFields: nil)!
        
        expect(sut, completionWithResult: .success((data, response))) {
            client.completeLoadingImage(with: data, response: response)
        }
    }
    
    func test_loadImageDataFromURL_doesNotDeliverResultAfterInstanceIsDeallocated() {
        let client = HTTPClientSpy()
        var sut: RemoteFeedImageDataLoader? = RemoteFeedImageDataLoader(client: client)
        
        var capturedResults = [HTTPClient.Result]()
        sut?.loadImageData(from: anyURL()) { result in
            capturedResults.append(result)
        }
        sut = nil
        client.completeLoadingImage(with: anyError())
        
        XCTAssertTrue(capturedResults.isEmpty)
    }
    
    //MARK: -Helpers
    
    private func makeSUT(file: StaticString = #filePath, line: UInt = #line) -> (RemoteFeedImageDataLoader, HTTPClientSpy) {
        let client = HTTPClientSpy()
        let sut = RemoteFeedImageDataLoader(client: client)
        trackForMemoryLeak(sut)
        trackForMemoryLeak(client)
        
        return (sut, client)
    }
    
    private func anyData() -> Data {
        return Data("invalid data".utf8)
    }
    
    private func failure(_ error: RemoteFeedImageDataLoader.Error) -> HTTPClient.Result {
        return .failure(error)
    }
    
    private func expect(_ sut: RemoteFeedImageDataLoader, completionWithResult expectedResult: HTTPClient.Result, action: (() -> ()), file: StaticString = #filePath, line: UInt = #line) {
        let url = anyURL()
        
        let exp = expectation(description: "wait for completion")
        sut.loadImageData(from: url) { result in
            switch (result, expectedResult) {
            case let (.failure(receivedError as NSError), .failure(expectedError as NSError)):
                XCTAssertEqual(expectedError.code, receivedError.code, file: file, line: line)
                XCTAssertEqual(expectedError.domain, receivedError.domain, file: file, line: line)
            case let (.success((receivedData, receivedResponse)), .success((expectedData, expectedResponse))):
                XCTAssertEqual(receivedData, expectedData, file: file, line: line)
                XCTAssertEqual(receivedResponse, expectedResponse, file: file, line: line)
            default:
                XCTFail("Expected \(expectedResult) got \(result) instead", file: file, line: line)
            }
            exp.fulfill()
        }
        
        action()
        
        wait(for: [exp], timeout: 1)
    }
    
    private class HTTPClientSpy: HTTPClient {
        private var messages: [(url: URL, completion: ((HTTPClient.Result) -> Void))] = []
        
        var capturedURLs: [URL] {
            messages.map { $0.url }
        }
        
        func get(from url: URL, completion: @escaping (HTTPClient.Result) -> Void) {
            messages.append((url, completion))
        }
        
        func completeLoadingImage(withStatusCode statusCode: Int, data: Data, at index: Int = 0) {
            let response = HTTPURLResponse(
                url: capturedURLs[index],
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil)
            messages[index].completion(.success((data, response!)))
        }
        
        func completeLoadingImage(with data: Data, response: HTTPURLResponse, at index: Int = 0) {
            messages[index].completion(.success((data, response)))
        }
        
        func completeLoadingImage(with error: Error, at index: Int = 0) {
            messages[index].completion(.failure(error))
        }
    }
}
