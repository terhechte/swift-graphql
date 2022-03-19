import Combine
import Foundation
import GraphQL
import SwiftGraphQL

/// Extensions to the core implementation that connect SwiftGraphQL's Selection to the execution
/// mechanisms of the client.
extension GraphQLClient {
    
    /// Turns selection into a request operation.
    public func createRequestOperation<T, TypeLock>(
        for selection: Selection<T, TypeLock>,
        as operationName: String? = nil,
        url request: URLRequest,
        policy: Operation.Policy
    ) -> Operation where TypeLock: GraphQLOperation {
        Operation(
            id: UUID().uuidString,
            kind: TypeLock.operationKind,
            request: request,
            policy: policy,
            types: Array(selection.types),
            args: selection.encode(operationName: operationName)
        )
    }
    
    // MARK: - Executors
    
    /// Executes a query against the client and returns a publisher that emits values from relevant exchanges.
    public func executeQuery<T, TypeLock>(
        for selection: Selection<T, TypeLock>,
        as operationName: String? = nil,
        url request: URLRequest,
        policy: Operation.Policy
    ) -> AnyPublisher<OperationResult, Never> where TypeLock: GraphQLHttpOperation {
        let operation = self.createRequestOperation(
            for: selection,
           as: operationName,
           url: request,
           policy: policy
        )
        return self.executeRequestOperation(operation: operation)
    }
    
    /// Executes a mutation against the client and returns a publisher that emits values from relevant exchanges.
    public func executeMutation<T, TypeLock>(
        for selection: Selection<T, TypeLock>,
        as operationName: String? = nil,
        url request: URLRequest,
        policy: Operation.Policy
    ) -> AnyPublisher<OperationResult, Never> where TypeLock: GraphQLHttpOperation {
        let operation = self.createRequestOperation(
            for: selection,
           as: operationName,
           url: request,
           policy: policy
        )
        return self.executeRequestOperation(operation: operation)
    }
    
    /// Executes a mutation against the client and returns a publisher that emits values from relevant exchanges.
    public func executeSubscription<T, TypeLock>(
        of selection: Selection<T, TypeLock>,
        as operationName: String? = nil,
        url request: URLRequest,
        policy: Operation.Policy
    ) -> AnyPublisher<OperationResult, Never> where TypeLock: GraphQLWebSocketOperation {
        let operation = self.createRequestOperation(
            for: selection,
           as: operationName,
           url: request,
           policy: policy
        )
        return self.executeRequestOperation(operation: operation)
    }
    
    // MARK: - Decoders
    
    /// Executes a query and returns a stream of decoded values.
    public func query<T, TypeLock>(
        for selection: Selection<T, TypeLock>,
        as operationName: String? = nil,
        url request: URLRequest,
        policy: Operation.Policy
    ) -> AnyPublisher<DecodedOperationResult<T>, Never> where T: Decodable, TypeLock: GraphQLHttpOperation & Decodable {
        self.executeQuery(for: selection, as: operationName, url: request, policy: policy)
            .map { result in result.decode(selection: selection) }
            .eraseToAnyPublisher()
    }
    
    /// Executes a mutation and returns a stream of decoded values.
    public func mutate<T, TypeLock>(
        for selection: Selection<T, TypeLock>,
        as operationName: String? = nil,
        url request: URLRequest,
        policy: Operation.Policy
    ) -> AnyPublisher<DecodedOperationResult<T>, Never> where T: Decodable, TypeLock: GraphQLHttpOperation & Decodable {
        self.executeMutation(for: selection, as: operationName, url: request, policy: policy)
            .map { result in result.decode(selection: selection) }
            .eraseToAnyPublisher()
    }
    
    /// Creates a subscription stream of decoded values from the given query.
    public func subscribe<T, TypeLock>(
        to selection: Selection<T, TypeLock>,
        as operationName: String? = nil,
        url request: URLRequest,
        policy: Operation.Policy
    ) -> AnyPublisher<DecodedOperationResult<T>, Never> where T: Decodable, TypeLock: GraphQLWebSocketOperation & Decodable {
        self.executeSubscription(of: selection, as: operationName, url: request, policy: policy)
            .map { result in result.decode(selection: selection) }
            .eraseToAnyPublisher()
    }
}

extension OperationResult {
    
    /// Decodes data in operation result using the selection decoder.
    fileprivate func decode<T: Decodable, TypeLock: Decodable>(
        selection: Selection<T, TypeLock>
    ) -> DecodedOperationResult<T> {
        var decoded = DecodedOperationResult<T>(
            operation: self.operation,
            data: nil,
            errors: self.errors,
            stale: self.stale
        )
        
        guard let data = self.data else {
            return decoded
        }
    
        do {
            let (result, errors) = try selection.decode(raw: data)
            
            decoded.data = result
            if let errors = errors {
                decoded.errors.append(contentsOf: errors.map { CombinedError.graphql($0) })
            }
        } catch(let err) {
            decoded.errors.append(CombinedError.parsing(err))
        }
        
        return decoded
    }
}