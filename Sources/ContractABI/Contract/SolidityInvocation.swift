//
//  Invocation.swift
//  Web3
//
//  Created by Josh Pyles on 6/5/18.
//

import Foundation
import Collections
#if !Web3CocoaPods
    import Web3
#endif

public enum InvocationError: Error {
    case contractNotDeployed
    case invalidConfiguration
    case invalidInvocation
    case encodingError
}

/// Represents invoking a given contract method with parameters
public protocol SolidityInvocation {
    associatedtype Function: SolidityFunction where Function.Invocation == Self
    /// The function that was invoked
    var method: Function { get }
    
    /// Parameters method was invoked with
    var parameters: [SolidityWrappedValue] { get }
    
    /// Handler for submitting calls and sends
    var handler: SolidityFunctionHandler { get }
    
    /// Estimate how much gas is needed to execute this transaction.
    func estimateGas(from: EthereumAddress?, gas: EthereumQuantity?, value: EthereumQuantity?, completion: @escaping (Result<EthereumQuantity, Error>) -> Void)
    
    /// Encodes the ABI for this invocation
    func encodeABI() -> EthereumData?
    
    init(method: Function, parameters: [ABIEncodable], handler: SolidityFunctionHandler)
}

// MARK: - Read Invocation

/// An invocation that is read-only. Should only use .call()
public struct SolidityReadInvocation: SolidityInvocation {
    
    public let method: SolidityConstantFunction
    public let parameters: [SolidityWrappedValue]
    
    public let handler: SolidityFunctionHandler
    
    public init(method: SolidityConstantFunction, parameters: [ABIEncodable], handler: SolidityFunctionHandler) {
        self.method = method
        self.parameters = zip(parameters, method.inputs).map { SolidityWrappedValue(value: $0, type: $1.type) }
        self.handler = handler
    }
    
    public func call(block: EthereumQuantityTag = .latest, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        do {
            let call = try createCall()
            let outputs = method.outputs ?? []
            handler.call(call, outputs: outputs, block: block, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }
}

// MARK: - Payable Invocation

/// An invocation that writes to the blockchain and can receive ETH. Should only use .send()
public struct SolidityPayableInvocation: SolidityInvocation {
    
    public let method: SolidityPayableFunction
    public let parameters: [SolidityWrappedValue]
    
    public let handler: SolidityFunctionHandler
    
    public init(method: SolidityPayableFunction, parameters: [ABIEncodable], handler: SolidityFunctionHandler) {
        self.method = method
        self.parameters = zip(parameters, method.inputs).map { SolidityWrappedValue(value: $0, type: $1.type) }
        self.handler = handler
    }

    public func createTransaction(
        nonce: EthereumQuantity? = nil,
        gasPrice: EthereumQuantity? = nil,
        maxFeePerGas: EthereumQuantity? = nil,
        maxPriorityFeePerGas: EthereumQuantity? = nil,
        gasLimit: EthereumQuantity? = nil,
        from: EthereumAddress? = nil,
        value: EthereumQuantity? = nil,
        accessList: OrderedDictionary<EthereumAddress, [EthereumData]> = [:],
        transactionType: EthereumTransaction.TransactionType = .legacy
    ) throws -> EthereumTransaction {
        guard let data = encodeABI() else { throw InvocationError.encodingError }
        guard let to = handler.address else { throw InvocationError.contractNotDeployed }

        return EthereumTransaction(
            nonce: nonce,
            gasPrice: gasPrice,
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas,
            gasLimit: gasLimit,
            from: from,
            to: to,
            value: value,
            data: data,
            accessList: accessList,
            transactionType: transactionType
        )
    }
    
    public func send(
        nonce: EthereumQuantity? = nil,
        gasPrice: EthereumQuantity? = nil,
        maxFeePerGas: EthereumQuantity? = nil,
        maxPriorityFeePerGas: EthereumQuantity? = nil,
        gasLimit: EthereumQuantity? = nil,
        from: EthereumAddress,
        value: EthereumQuantity? = nil,
        accessList: OrderedDictionary<EthereumAddress, [EthereumData]> = [:],
        transactionType: EthereumTransaction.TransactionType = .legacy,
        completion: @escaping (Result<EthereumData, Error>) -> Void
    ) {
        do {
            let transaction = try createTransaction(
                nonce: nonce,
                gasPrice: gasPrice,
                maxFeePerGas: maxFeePerGas,
                maxPriorityFeePerGas: maxPriorityFeePerGas,
                gasLimit: gasLimit,
                from: from,
                value: value,
                accessList: accessList,
                transactionType: transactionType
            )
            handler.send(transaction, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }
}

// MARK: - Non Payable Invocation

/// An invocation that writes to the blockchain and cannot receive ETH. Should only use .send().
public struct SolidityNonPayableInvocation: SolidityInvocation {
    
    public let method: SolidityNonPayableFunction
    public let parameters: [SolidityWrappedValue]
    
    public let handler: SolidityFunctionHandler
    
    public init(method: SolidityNonPayableFunction, parameters: [ABIEncodable], handler: SolidityFunctionHandler) {
        self.method = method
        self.parameters = zip(parameters, method.inputs).map { SolidityWrappedValue(value: $0, type: $1.type) }
        self.handler = handler
    }
    
    public func createTransaction(
        nonce: EthereumQuantity? = nil,
        gasPrice: EthereumQuantity? = nil,
        maxFeePerGas: EthereumQuantity? = nil,
        maxPriorityFeePerGas: EthereumQuantity? = nil,
        gasLimit: EthereumQuantity? = nil,
        from: EthereumAddress? = nil,
        accessList: OrderedDictionary<EthereumAddress, [EthereumData]> = [:],
        transactionType: EthereumTransaction.TransactionType = .legacy
    ) throws -> EthereumTransaction {
        guard let data = encodeABI() else { throw InvocationError.encodingError }
        guard let to = handler.address else { throw InvocationError.contractNotDeployed }

        return EthereumTransaction(
            nonce: nonce,
            gasPrice: gasPrice,
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas,
            gasLimit: gasLimit,
            from: from,
            to: to,
            value: nil,
            data: data,
            accessList: accessList,
            transactionType: transactionType
        )
    }
    
    public func send(
        nonce: EthereumQuantity? = nil,
        gasPrice: EthereumQuantity? = nil,
        maxFeePerGas: EthereumQuantity? = nil,
        maxPriorityFeePerGas: EthereumQuantity? = nil,
        gasLimit: EthereumQuantity? = nil,
        from: EthereumAddress,
        accessList: OrderedDictionary<EthereumAddress, [EthereumData]> = [:],
        transactionType: EthereumTransaction.TransactionType = .legacy,
        completion: @escaping (Result<EthereumData, Error>) -> Void
    ) {
        do {
            let transaction = try createTransaction(
                nonce: nonce,
                gasPrice: gasPrice,
                maxFeePerGas: maxFeePerGas,
                maxPriorityFeePerGas: maxPriorityFeePerGas,
                gasLimit: gasLimit,
                from: from,
                accessList: accessList,
                transactionType: transactionType
            )
            handler.send(transaction, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }
}

// MARK: - PromiseKit convenience

public extension SolidityInvocation {
    
    // Default Implementations
    func createCall(from: EthereumAddress? = nil,
                    gas: EthereumQuantity? = nil,
                    gasPrice: EthereumQuantity? = nil,
                    value: EthereumQuantity? = nil) throws -> EthereumCall {
        
        guard let data = encodeABI() else { throw InvocationError.encodingError }
        guard let to = handler.address else { throw InvocationError.contractNotDeployed }
        return EthereumCall(from: from, to: to, gas: gas, gasPrice: gasPrice, value: value, data: data)
    }
    
    func estimateGas(from: EthereumAddress? = nil, gas: EthereumQuantity? = nil, value: EthereumQuantity? = nil, completion: @escaping (Result<EthereumQuantity, Error>) -> Void) {
        do {
            let call = try createCall(from: from, gas: gas, value: value)
            handler.estimateGas(call, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }
    
    func encodeABI() -> EthereumData? {
        if let hexString = try? ABI.encodeFunctionCall(self) {
            return try? EthereumData(ethereumValue: hexString)
        }
        return nil
    }
}

// MARK: - Contract Creation

/// Represents a contract creation invocation
public struct SolidityConstructorInvocation {
    public let byteCode: EthereumData
    public let parameters: [SolidityWrappedValue]
    public let payable: Bool
    public let handler: SolidityFunctionHandler
    
    public init(byteCode: EthereumData, parameters: [SolidityWrappedValue], payable: Bool, handler: SolidityFunctionHandler) {
        self.byteCode = byteCode
        self.parameters = parameters
        self.handler = handler
        self.payable = payable
    }

    public func createTransaction(
        nonce: EthereumQuantity? = nil,
        gasPrice: EthereumQuantity? = nil,
        maxFeePerGas: EthereumQuantity? = nil,
        maxPriorityFeePerGas: EthereumQuantity? = nil,
        gasLimit: EthereumQuantity? = nil,
        from: EthereumAddress? = nil,
        value: EthereumQuantity? = nil,
        accessList: OrderedDictionary<EthereumAddress, [EthereumData]> = [:],
        transactionType: EthereumTransaction.TransactionType = .legacy
    ) throws -> EthereumTransaction {
        guard payable == true || value == nil || value == 0 else { throw InvocationError.invalidInvocation }
        guard let data = encodeABI() else { throw InvocationError.encodingError }

        return EthereumTransaction(
            nonce: nonce,
            gasPrice: gasPrice,
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas,
            gasLimit: gasLimit,
            from: from,
            to: nil,
            value: value,
            data: data,
            accessList: accessList,
            transactionType: transactionType
        )
    }
    
    public func send(
        nonce: EthereumQuantity? = nil,
        gasPrice: EthereumQuantity? = nil,
        maxFeePerGas: EthereumQuantity? = nil,
        maxPriorityFeePerGas: EthereumQuantity? = nil,
        gasLimit: EthereumQuantity? = nil,
        from: EthereumAddress,
        value: EthereumQuantity? = nil,
        accessList: OrderedDictionary<EthereumAddress, [EthereumData]> = [:],
        transactionType: EthereumTransaction.TransactionType = .legacy,
        completion: @escaping (Result<EthereumData, Error>) -> Void
    ) {
        do {
            let transaction = try createTransaction(
                nonce: nonce,
                gasPrice: gasPrice,
                maxFeePerGas: maxFeePerGas,
                maxPriorityFeePerGas: maxPriorityFeePerGas,
                gasLimit: gasLimit,
                from: from,
                value: value,
                accessList: accessList,
                transactionType: transactionType
            )
            handler.send(transaction, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }
    
    public func encodeABI() -> EthereumData? {
        // The data for creating a new contract is the bytecode of the contract + any input params serialized in the standard format.
        var dataString = "0x"
        dataString += byteCode.hex().replacingOccurrences(of: "0x", with: "")
        if parameters.count > 0, let encodedParams = try? ABI.encodeParameters(parameters) {
            dataString += encodedParams.replacingOccurrences(of: "0x", with: "")
        }
        return try? EthereumData(ethereumValue: dataString)
    }
}
