//
//  RetryableError.swift
//  AmpleError
//
//  Created by Carl Funk on 10/15/24.
//  Copyright © 2024 Carl Funk. All rights reserved.
//

import Foundation

public struct RetryableError: LocalizedError {
    public typealias RetryAction = () -> Void
    
    public var underlying: Error
    public var retryAction: RetryAction
    
    public init(
        underlying: Error,
        retryAction: @escaping RetryAction
    ) {
        self.underlying = underlying
        self.retryAction = retryAction
    }
    
    public var errorDescription: String? {
        guard let localizedError = underlying as? LocalizedError else {
            return underlying.localizedDescription
        }
        return localizedError.errorDescription
    }
}
