# Multisig Wallet Smart Contract

Link web3 deploy contract: [Link deploy](https://multisigweb3.netlify.app)

## Overview

The **Multisig Wallet** contract allows multiple owners to securely manage funds and perform various types of transactions with a required number of confirmations. It supports **Ether (native token)**, **ERC20**, **ERC721**, and **ERC1155** token transactions. The contract includes owner management, transaction cancellation, and built-in security mechanisms like **ReentrancyGuard**.

This contract ensures that **no single owner can move funds alone**, making it suitable for team wallets, DAO treasuries, or secure fund management.

---

## Features

- **Multisignature Transactions**: Requires multiple confirmations to execute any transaction.
- **Token Support**: Handles Ether, ERC20, ERC721, and ERC1155 transfers.
- **Owner Management**: Add or remove owners dynamically and adjust required signatures.
- **Transaction Expiry**: Transactions expire after 1 day if not executed.
- **Cancel Votes**: Owners can vote to cancel unconfirmed transactions.
- **Security**: Implements ReentrancyGuard and ensures recipients are either EOAs or EIP-7702 upgraded addresses.
- **Event Logging**: Emits events for all key actions to allow easy frontend tracking.

---

## Transaction Types

The contract supports the following transaction types:

| Type | Description |
|------|-------------|
| `WithdrawNativeToken` | Send Ether to an owner. |
| `WithdrawERC20` | Send ERC20 tokens to an owner. |
| `WithdrawERC721` | Send an ERC721 token to an owner. |
| `WithdrawERC1155` | Send ERC1155 tokens to an owner. |
| `AddOwner` | Add a new wallet owner. |
| `RemoveOwner` | Remove an existing wallet owner. |
| `ChangeRequiredSignatures` | Update the number of required signatures for transactions. |

---

## Contract Functions

### Write Functions

#### Transaction Submission & Execution

- **`submitWithdrawNativeToken(address _to, uint256 _amount)`**  
  Propose an Ether transfer to an owner.

- **`submitWithdrawERC20(address _to, address _tokenAddress, uint256 _amount)`**  
  Propose an ERC20 token transfer to an owner.

- **`submitWithdrawERC721(address _to, address _tokenAddress, uint256 _tokenId)`**  
  Propose an ERC721 token transfer to an owner.

- **`submitWithdrawERC1155(address _to, address _tokenAddress, uint256 _tokenId, uint256 _amount)`**  
  Propose an ERC1155 token transfer to an owner.

- **`confirmTransaction(uint256 _txIndex)`**  
  Confirm a pending transaction.

- **`executeTransaction(uint256 _txIndex)`**  
  Execute a confirmed transaction.

- **`revokeConfirmation(uint256 _txIndex)`**  
  Revoke a previously submitted confirmation.

- **`cancelTransaction(uint256 _txIndex)`**  
  Vote to cancel a transaction that hasn’t been executed yet.

#### Owner Management

- **`proposeAddOwner(address _newOwner)`**  
  Propose adding a new owner.

- **`proposeRemoveOwner(address _owner)`**  
  Propose removing an existing owner.

- **`proposeChangeRequiredSignatures(uint256 _newRequiredSignatures)`**  
  Propose changing the required number of signatures for transactions.

> All owner management proposals are executed through `executeTransaction` after reaching required confirmations.

---

### Read Functions

- **`getTransactionCount()`**  
  Returns the total number of submitted transactions.

- **`getTransaction(uint256 _txIndex)`**  
  Returns detailed information about a specific transaction, including type, recipient, token address, amount, confirmations, and execution status.

- **`getOwners()`**  
  Returns the list of current owners.

- **`getNativeTokenBalance()`**  
  Returns the Ether balance of the wallet.

- **`getERC20TokenBalance(address tokenAddress)`**  
  Returns the ERC20 token balance for the wallet.

---

### Security Checks

- Only **owners** can propose, confirm, or execute transactions.
- Transactions require **`requiredSignatures` confirmations** to execute.
- Transactions expire after **1 day**.
- Supports **EIP-7702 upgraded EOAs** for smart contract wallet compatibility.
- **ReentrancyGuard** applied to prevent reentrancy attacks on execute functions.

---

### Events

The contract emits events for all major actions:

- `Deposit` – Ether deposit.
- `ProposeTransaction` – Transaction proposal.
- `ConfirmTransaction` – Transaction confirmation.
- `ExecuteTransaction` – Transaction execution.
- `RevokeConfirmation` – Revoking a confirmation.
- `CancelTransaction` – Canceling a transaction via owner votes.
- `OwnerAdded` / `OwnerRemoved` – Owner management.
- `RequiredSignaturesChanged` – Signature requirement updates.
- `WithdrawERC721` / `WithdrawERC1155` – NFT transfers.

---

### Notes

- Max **10 owners** allowed.
- Recipient of token transfers must be **an owner and either an EOA or EIP-7702 upgraded EOA**.
- ERC1155 transfers support **amount > 0 only**.
- Transactions that reach required confirmations cannot be canceled.
