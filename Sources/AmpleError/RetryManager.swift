//
//  RetryManager.swift
//  AmpleError
//
//  Created by Carl Funk on 10/15/24.
//  Copyright © 2024 Carl Funk. All rights reserved.
//

import Foundation

public final class RetryManager: ObservableObject {
    public enum PresentationBehavior {
        case acceptsSuppression
        case prefersDisplay
    }
    
    /// Retry starting point
    public enum RetryBehavior {
        case ancestor
        case descendants
        case siblings
    }
    
    private struct ParentError: LocalizedError { }
    
    private weak var parentNode: RetryManager?
    private var childrenNodes: [RetryManager]
    
    public let presentationBehavior: PresentationBehavior
    public let retryBehavior: RetryBehavior
    
    @Published public private(set) var errors: [LocalizedError]
    @Published public private(set) var presentationSuppressed: Bool
    
    private init(
        parentNode: RetryManager? = nil,
        childrenNodes: [RetryManager] = [],
        presentationBehavior: PresentationBehavior = .acceptsSuppression,
        retryBehavior: RetryBehavior = .ancestor,
        errors: [LocalizedError] = [],
        presentationSuppressed: Bool = false
    ) {
        self.parentNode = parentNode
        self.childrenNodes = childrenNodes
        self.presentationBehavior = presentationBehavior
        self.retryBehavior = retryBehavior
        self.errors = errors
        self.presentationSuppressed = presentationSuppressed
    }
    
    deinit {
        parentNode?.childrenNodes.removeAll(where: { $0 === self })
    }
    
    // MARK: - Nodes
    
    public static func root(
        presentationBehavior: PresentationBehavior = .acceptsSuppression,
        retryBehavior: RetryBehavior = .ancestor
    ) -> RetryManager {
        RetryManager(
            presentationBehavior: presentationBehavior, 
            retryBehavior: retryBehavior
        )
    }
    
    public func node(
        presentationBehavior: PresentationBehavior? = nil,
        retryBehavior: RetryBehavior? = nil
    ) -> RetryManager {
        let childNode = RetryManager(
            parentNode: self, 
            presentationBehavior: presentationBehavior ?? self.presentationBehavior, 
            retryBehavior: retryBehavior ?? self.retryBehavior)
        childrenNodes.append(childNode)
        return childNode
    }
    
    // MARK: - Public
    
    public var showError: Bool {
        hasError && !presentationSuppressed
    }
    
    public var hasError: Bool {
        !errors.isEmpty
    }
    
    public func receive(error: LocalizedError) {
        errors.append(error)
        notifyParent()
    }
    
    public func retry() {
        internalRetry()
    }
    
    // MARK: - Retry
    
    private func internalRetry() {
        guard let parentNode else {
            retrySelfAndDescendants()
            return
        }
        
        switch retryBehavior {
        case .ancestor:
            parentNode.internalRetry()
        case .descendants:
            retrySelfAndDescendants()
        case .siblings:
            parentNode.retryDescendants()
        }
    }
    
    private func retrySelf() {
        errors.forEach { error in
            switch error {
            case let retryableError as RetryableError:
                retryableError.retryAction()
            default:
                break
            }
        }
        
        errors = []
        presentationSuppressed = false
    }
    
    private func retryDescendants() {
        childrenNodes.forEach {
            $0.retrySelf()
            $0.retryDescendants()
        }
    }
    
    private func retrySelfAndDescendants() {
        retrySelf()
        retryDescendants()
    }
    
    // MARK: - Presentation Modification
    
    private func notifyParent() {
        guard let parentNode else {
            suppressDescendantsPresentation()
            return
        }
        
        parentNode.suppressDescendantsPresentationIfRequired()
    }
    
    private func suppressDescendantsPresentation() {
        childrenNodes.forEach {
            $0.presentationSuppressed = true
            $0.suppressDescendantsPresentation()
        }
    }
    
    private func suppressDescendantsPresentationIfRequired() {
        let childrenNodesWithError = childrenNodes
            .filter { $0.hasError }
        
        let hasPrefersDisplay = childrenNodes
            .contains(where: { $0.presentationBehavior == .prefersDisplay })
        
        if !hasPrefersDisplay && childrenNodesWithError.count > 1 {
            errors.append(ParentError())
            suppressDescendantsPresentation()
        } else {
            childrenNodes.forEach { $0.suppressDescendantsPresentation() }
        }
    }
}
