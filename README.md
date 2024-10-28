# Multisig Wallet Smart Contract

## Overview

The Multisig Wallet contract allows multiple owners to securely manage funds and perform transactions with a required number of confirmations. It supports both Ether and ERC20 token transactions, enhancing security against unauthorized access.

## Features

- **Multisignature Transactions**: Requires multiple confirmations to execute transactions.
- **Token Support**: Allows sending both Ether and ERC20 tokens.
- **Owner Management**: Dynamically add or remove owners and adjust required signatures.
- **Transaction Expiry**: Transactions can expire after a certain time.
- **Reentrancy Protection**: Implements ReentrancyGuard to prevent reentrancy attacks.

## Contract Functions

### Write Functions

1. **`submitTokenTransaction(address _to, address _tokenAddress, uint256 _amount)`**
   - Submits a token transfer transaction for confirmation.
   - **Parameters**:
     - `_to`: The recipient's address (must be an owner).
     - `_tokenAddress`: The address of the ERC20 token to be transferred.
     - `_amount`: The amount of tokens to transfer.
   - Emits a `SubmitTransaction` event.

2. **`submitTransaction(address _to, uint256 _amount)`**
   - Submits an Ether transfer transaction for confirmation.
   - **Parameters**:
     - `_to`: The recipient's address (must be an owner).
     - `_amount`: The amount of Ether to transfer.
   - Emits a `SubmitTransaction` event.

3. **`confirmTransaction(uint256 _txIndex)`**
   - Confirms a submitted transaction.
   - **Parameters**:
     - `_txIndex`: The index of the transaction to confirm.
   - Emits a `ConfirmTransaction` event.

4. **`executeTransaction(uint256 _txIndex)`**
   - Executes a confirmed transaction.
   - **Parameters**:
     - `_txIndex`: The index of the transaction to execute.
   - Emits an `ExecuteTransaction` event.

5. **`revokeConfirmation(uint256 _txIndex)`**
   - Revokes a confirmation for a transaction.
   - **Parameters**:
     - `_txIndex`: The index of the transaction to revoke confirmation for.
   - Emits a `RevokeConfirmation` event.

6. **`cancelTransaction(uint256 _txIndex)`**
   - Cancels a transaction that has not been executed.
   - **Parameters**:
     - `_txIndex`: The index of the transaction to cancel.
   - Emits a `CancelTransaction` event.

7. **`submitAddOwner(address _newOwner)`**
   - Submits a request to add a new owner.
   - **Parameters**:
     - `_newOwner`: The address of the new owner.
   - Emits a `SubmitTransaction` event.

8. **`executeAddOwner(uint256 _txIndex)`**
   - Executes the addition of a new owner after sufficient confirmations.
   - **Parameters**:
     - `_txIndex`: The index of the transaction to execute.
   - Emits `OwnerAdded` and `ExecuteTransaction` events.

9. **`submitRemoveOwner(address _owner)`**
   - Submits a request to remove an existing owner.
   - **Parameters**:
     - `_owner`: The address of the owner to remove.
   - Emits a `SubmitTransaction` event.

10. **`executeRemoveOwner(uint256 _txIndex)`**
    - Executes the removal of an owner after sufficient confirmations.
    - **Parameters**:
      - `_txIndex`: The index of the transaction to execute.
    - Emits `OwnerRemoved` and `ExecuteTransaction` events.

11. **`submitSetRequiredSignatures(uint256 _newRequiredSignatures)`**
    - Submits a request to change the number of required signatures.
    - **Parameters**:
      - `_newRequiredSignatures`: The new number of required signatures.
    - Emits a `SubmitTransaction` event.

12. **`executeSetRequiredSignatures(uint256 _txIndex)`**
    - Executes the change of required signatures after sufficient confirmations.
    - **Parameters**:
      - `_txIndex`: The index of the transaction to execute.
    - Emits `RequiredSignaturesChanged` and `ExecuteTransaction` events.

### Read Functions

1. **`getTransactionCount()`**
   - Returns the total number of transactions submitted to the contract.

2. **`getTransaction(uint256 _txIndex)`**
   - Retrieves details of a specific transaction.
   - **Parameters**:
     - `_txIndex`: The index of the transaction.
   - **Returns**:
     - `to`: Recipient address.
     - `value`: Amount of Ether or tokens to be transferred.
     - `executed`: Whether the transaction has been executed.
     - `confirmations`: Number of confirmations received.
     - `createdAt`: Timestamp of transaction creation.
     - `isTokenTransaction`: Boolean indicating if it’s a token transaction.
     - `tokenAddress`: Address of the token involved, if applicable.

3. **`getOwners()`**
   - Returns the list of current owners.

