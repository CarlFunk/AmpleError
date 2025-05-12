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
    
    public let tag: String
    public let presentationBehavior: PresentationBehavior
    public let retryBehavior: RetryBehavior
    
    public private(set) var errors: [LocalizedError]
    public private(set) var presentationSuppressed: Bool
    
    private init(
        tag: String = UUID().uuidString,
        parentNode: RetryManager? = nil,
        childrenNodes: [RetryManager] = [],
        presentationBehavior: PresentationBehavior = .acceptsSuppression,
        retryBehavior: RetryBehavior = .ancestor,
        errors: [LocalizedError] = [],
        presentationSuppressed: Bool = false
    ) {
        self.tag = tag
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
        tag: String = UUID().uuidString,
        presentationBehavior: PresentationBehavior = .acceptsSuppression,
        retryBehavior: RetryBehavior = .ancestor
    ) -> RetryManager {
        RetryManager(
            tag: tag,
            presentationBehavior: presentationBehavior,
            retryBehavior: retryBehavior
        )
    }
    
    public func node(
        tag: String = UUID().uuidString,
        presentationBehavior: PresentationBehavior = .acceptsSuppression,
        retryBehavior: RetryBehavior = .ancestor
    ) -> RetryManager {
        let childNode = RetryManager(
            tag: tag,
            parentNode: self,
            presentationBehavior: presentationBehavior,
            retryBehavior: retryBehavior)
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
    
    public var hasSingleError: Bool {
        errors.count == 1
    }
    
    public var hasRetryableError: Bool {
        errors.contains(where: { ($0 as? RetryableError) != nil || ($0 as? ParentError) != nil })
    }
    
    public func receive(error: LocalizedError) {
        errors.append(error)
        updateUI()
        notifyParent()
    }
    
    public func removeAllErrors() {
        errors.removeAll()
        updateUI()
    }
    
    public func remove(error: LocalizedError) {
        errors.removeAll(where: { $0.localizedDescription == error.localizedDescription })
        updateUI()
    }
    
    public func retry() {
        internalRetry()
    }
    
    public func detach() {
        parentNode?.childrenNodes.removeAll(where: { $0 === self })
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
            
            remove(error: error)
        }
        
        unsuppressPresentation()
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
    
    private func unsuppressPresentation() {
        presentationSuppressed = false
        updateUI()
    }
    
    private func suppressPresentation() {
        presentationSuppressed = true
        updateUI()
    }
    
    private func suppressDescendantsPresentation() {
        childrenNodes.forEach {
            $0.suppressPresentation()
            $0.suppressDescendantsPresentation()
        }
    }
    
    private func suppressDescendantsPresentationIfRequired() {
        let childrenNodesWithError = childrenNodes
            .filter { $0.hasError }
        
        let hasPrefersDisplay = childrenNodes
            .contains(where: { $0.presentationBehavior == .prefersDisplay })
        
        if !hasPrefersDisplay && (childrenNodesWithError.count > 1 || childrenNodesWithError.count == childrenNodes.count) {
            receive(error: ParentError())
        } else {
            childrenNodesWithError.forEach { $0.suppressDescendantsPresentation() }
        }
    }
    
    // MARK: - Private
    
    private func updateUI() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.objectWillChange.send()
        }
    }
}
