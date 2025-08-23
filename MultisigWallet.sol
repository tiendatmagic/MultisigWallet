// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract MultisigWallet is ReentrancyGuard {
    using SafeERC20 for IERC20;

    address[] private owners;
    mapping(address => bool) public isOwner;
    mapping(uint256 => uint256) private cancelVotes;
    mapping(uint256 => mapping(address => bool)) private hasVotedCancel;
    uint256 public requiredSignatures;

    enum TransactionType {
        WithdrawNativeToken,
        WithdrawERC20,
        AddOwner,
        RemoveOwner,
        ChangeRequiredSignatures,
        WithdrawERC721,
        WithdrawERC1155
    }

    struct Transaction {
        address to;
        uint256 value;
        bool executed;
        uint256 confirmations;
        uint256 createdAt;
        address tokenAddress;
        mapping(address => bool) isConfirmed;
        uint256 requiredSignatures;
        TransactionType txType;
        uint256 data;
    }

    Transaction[] private transactions;

    event Deposit(address indexed sender, uint256 amount);
    event ProposeTransaction(address indexed owner, uint256 indexed txIndex);
    event ConfirmTransaction(address indexed owner, uint256 indexed txIndex);
    event ExecuteTransaction(address indexed owner, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed owner, uint256 indexed txIndex);
    event CancelTransaction(address indexed owner, uint256 indexed txIndex);
    event RequiredSignaturesChanged(uint256 newRequiredSignatures);
    event OwnerAdded(address indexed newOwner);
    event OwnerRemoved(address indexed removedOwner);
    event WithdrawERC721(
        address indexed owner,
        address indexed to,
        address indexed tokenAddress,
        uint256 tokenId
    );
    event WithdrawERC1155(
        address indexed owner,
        address indexed to,
        address indexed tokenAddress,
        uint256 tokenId,
        uint256 amount
    );

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    modifier txExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 _txIndex) {
        require(
            !transactions[_txIndex].executed,
            "Transaction already executed"
        );
        _;
    }

    modifier notConfirmed(uint256 _txIndex) {
        require(
            !transactions[_txIndex].isConfirmed[msg.sender],
            "Transaction already confirmed"
        );
        _;
    }

    function isEIP7702(address _addr) internal view returns (bool) {
        bytes memory code = _addr.code;
        if (code.length != 23) return false;
        if (code[0] != 0xef || code[1] != 0x01 || code[2] != 0x00) return false;
        return true;
    }

    constructor(address[] memory _owners, uint256 _requiredSignatures) {
        require(_owners.length > 0, "Owners required");
        require(_owners.length <= 10, "Max 10 owners allowed");
        require(
            _requiredSignatures > 0 && _requiredSignatures <= _owners.length,
            "Invalid number of required signatures"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");
            require(
                owner.code.length == 0 || isEIP7702(owner),
                "Owner must be EOA or EIP-7702 upgraded EOA"
            );
            isOwner[owner] = true;
            owners.push(owner);
        }
        requiredSignatures = _requiredSignatures;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function getNativeTokenBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getERC20TokenBalance(
        address tokenAddress
    ) public view returns (uint256) {
        require(tokenAddress != address(0), "Invalid token address");
        IERC20 token = IERC20(tokenAddress);
        return token.balanceOf(address(this));
    }

    function submitWithdrawERC20(
        address _to,
        address _tokenAddress,
        uint256 _amount
    ) public onlyOwner {
        require(_to != address(0), "Invalid recipient address");
        require(isOwner[_to], "Recipient must be an owner");
        require(
            _to.code.length == 0 || isEIP7702(_to),
            "Recipient must be EOA or EIP-7702 upgraded EOA"
        );
        require(_amount > 0, "Amount must be greater than 0");
        IERC20 token = IERC20(_tokenAddress);
        require(
            token.balanceOf(address(this)) >= _amount,
            "Not enough token balance"
        );

        uint256 txIndex = transactions.length;
        transactions.push();
        Transaction storage newTx = transactions[txIndex];
        newTx.to = _to;
        newTx.value = _amount;
        newTx.executed = false;
        newTx.confirmations = 0;
        newTx.createdAt = block.timestamp;
        newTx.tokenAddress = _tokenAddress;
        newTx.requiredSignatures = requiredSignatures;
        newTx.txType = TransactionType.WithdrawERC20;
        newTx.data = 0;
        emit ProposeTransaction(msg.sender, txIndex);
    }

    function submitWithdrawNativeToken(
        address _to,
        uint256 _amount
    ) public onlyOwner {
        require(_to != address(0), "Invalid recipient address");
        require(isOwner[_to], "Recipient must be an owner");
        require(
            _to.code.length == 0 || isEIP7702(_to),
            "Recipient must be EOA or EIP-7702 upgraded EOA"
        );
        require(_amount > 0, "Amount must be greater than 0");
        require(
            address(this).balance >= _amount,
            "Not enough native token balance"
        );

        uint256 txIndex = transactions.length;
        transactions.push();
        Transaction storage newTx = transactions[txIndex];
        newTx.to = _to;
        newTx.value = _amount;
        newTx.executed = false;
        newTx.confirmations = 0;
        newTx.createdAt = block.timestamp;
        newTx.tokenAddress = address(0);
        newTx.requiredSignatures = requiredSignatures;
        newTx.txType = TransactionType.WithdrawNativeToken;
        newTx.data = 0;
        emit ProposeTransaction(msg.sender, txIndex);
    }

    function submitWithdrawERC721(
        address _to,
        address _tokenAddress,
        uint256 _tokenId
    ) public onlyOwner {
        require(_to != address(0), "Invalid recipient address");
        require(isOwner[_to], "Recipient must be an owner");
        require(
            _to.code.length == 0 || isEIP7702(_to),
            "Recipient must be EOA or EIP-7702 upgraded EOA"
        );
        require(_tokenAddress != address(0), "Invalid token address");
        IERC721 token = IERC721(_tokenAddress);
        require(
            token.ownerOf(_tokenId) == address(this),
            "Contract does not own this token"
        );

        uint256 txIndex = transactions.length;
        transactions.push();
        Transaction storage newTx = transactions[txIndex];
        newTx.to = _to;
        newTx.value = 0;
        newTx.executed = false;
        newTx.confirmations = 0;
        newTx.createdAt = block.timestamp;
        newTx.tokenAddress = _tokenAddress;
        newTx.requiredSignatures = requiredSignatures;
        newTx.txType = TransactionType.WithdrawERC721;
        newTx.data = _tokenId;
        emit ProposeTransaction(msg.sender, txIndex);
    }

    function submitWithdrawERC1155(
        address _to,
        address _tokenAddress,
        uint256 _tokenId,
        uint256 _amount
    ) public onlyOwner {
        require(_to != address(0), "Invalid recipient address");
        require(isOwner[_to], "Recipient must be an owner");
        require(
            _to.code.length == 0 || isEIP7702(_to),
            "Recipient must be EOA or EIP-7702 upgraded EOA"
        );
        require(_tokenAddress != address(0), "Invalid token address");
        require(_amount > 0, "Amount must be greater than 0");
        IERC1155 token = IERC1155(_tokenAddress);
        require(
            token.balanceOf(address(this), _tokenId) >= _amount,
            "Insufficient token balance"
        );

        uint256 txIndex = transactions.length;
        transactions.push();
        Transaction storage newTx = transactions[txIndex];
        newTx.to = _to;
        newTx.value = _amount;
        newTx.executed = false;
        newTx.confirmations = 0;
        newTx.createdAt = block.timestamp;
        newTx.tokenAddress = _tokenAddress;
        newTx.requiredSignatures = requiredSignatures;
        newTx.txType = TransactionType.WithdrawERC1155;
        newTx.data = _tokenId;
        emit ProposeTransaction(msg.sender, txIndex);
    }

    function proposeAddOwner(address _newOwner) public onlyOwner {
        require(_newOwner != address(0), "Invalid owner address");
        require(!isOwner[_newOwner], "Owner already exists");
        require(
            _newOwner.code.length == 0 || isEIP7702(_newOwner),
            "New owner must be EOA or EIP-7702 upgraded EOA"
        );
        require(owners.length < 10, "Max 10 owners allowed");

        uint256 txIndex = transactions.length;
        transactions.push();
        Transaction storage newTx = transactions[txIndex];
        newTx.to = _newOwner;
        newTx.value = 0;
        newTx.executed = false;
        newTx.confirmations = 0;
        newTx.createdAt = block.timestamp;
        newTx.tokenAddress = address(0);
        newTx.requiredSignatures = requiredSignatures;
        newTx.txType = TransactionType.AddOwner;
        newTx.data = 0;
        emit ProposeTransaction(msg.sender, txIndex);
    }

    function proposeRemoveOwner(address _owner) public onlyOwner {
        require(isOwner[_owner], "Not an owner");
        require(owners.length > 1, "Cannot remove the last owner");

        uint256 txIndex = transactions.length;
        transactions.push();
        Transaction storage newTx = transactions[txIndex];
        newTx.to = _owner;
        newTx.value = 0;
        newTx.executed = false;
        newTx.confirmations = 0;
        newTx.createdAt = block.timestamp;
        newTx.tokenAddress = address(0);
        newTx.requiredSignatures = requiredSignatures;
        newTx.txType = TransactionType.RemoveOwner;
        newTx.data = 0;
        emit ProposeTransaction(msg.sender, txIndex);
    }

    function proposeChangeRequiredSignatures(
        uint256 _newRequiredSignatures
    ) public onlyOwner {
        require(
            _newRequiredSignatures > 0 &&
                _newRequiredSignatures <= owners.length,
            "Invalid number of required signatures"
        );

        uint256 txIndex = transactions.length;
        transactions.push();
        Transaction storage newTx = transactions[txIndex];
        newTx.to = address(0);
        newTx.value = 0;
        newTx.executed = false;
        newTx.confirmations = 0;
        newTx.createdAt = block.timestamp;
        newTx.tokenAddress = address(0);
        newTx.requiredSignatures = requiredSignatures;
        newTx.txType = TransactionType.ChangeRequiredSignatures;
        newTx.data = _newRequiredSignatures;
        emit ProposeTransaction(msg.sender, txIndex);
    }

    function confirmTransaction(
        uint256 _txIndex
    )
        public
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        Transaction storage transaction = transactions[_txIndex];
        require(
            block.timestamp <= transaction.createdAt + 1 days,
            "Transaction expired"
        );
        require(
            transaction.confirmations < transaction.requiredSignatures,
            "Transaction already has enough confirmations"
        );

        transaction.isConfirmed[msg.sender] = true;
        transaction.confirmations += 1;
        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(
        uint256 _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) nonReentrant {
        Transaction storage transaction = transactions[_txIndex];
        require(
            transaction.confirmations >= transaction.requiredSignatures,
            "Not enough confirmations"
        );
        require(
            block.timestamp <= transaction.createdAt + 1 days,
            "Transaction expired"
        );

        bool isTransferType = (transaction.txType ==
            TransactionType.WithdrawNativeToken ||
            transaction.txType == TransactionType.WithdrawERC20 ||
            transaction.txType == TransactionType.WithdrawERC721 ||
            transaction.txType == TransactionType.WithdrawERC1155);
        if (isTransferType) {
            require(
                transaction.to.code.length == 0 || isEIP7702(transaction.to),
                "Recipient must be EOA or EIP-7702 upgraded EOA"
            );
        }

        if (transaction.txType == TransactionType.WithdrawNativeToken) {
            require(
                address(this).balance >= transaction.value,
                "Insufficient contract balance"
            );
            (bool success, ) = transaction.to.call{value: transaction.value}(
                ""
            );
            require(success, "Native token transaction to recipient failed");
        } else if (transaction.txType == TransactionType.WithdrawERC20) {
            IERC20 token = IERC20(transaction.tokenAddress);
            token.safeTransfer(transaction.to, transaction.value);
        } else if (transaction.txType == TransactionType.WithdrawERC721) {
            IERC721 token = IERC721(transaction.tokenAddress);
            token.safeTransferFrom(
                address(this),
                transaction.to,
                transaction.data
            );
            emit WithdrawERC721(
                msg.sender,
                transaction.to,
                transaction.tokenAddress,
                transaction.data
            );
        } else if (transaction.txType == TransactionType.WithdrawERC1155) {
            IERC1155 token = IERC1155(transaction.tokenAddress);
            token.safeTransferFrom(
                address(this),
                transaction.to,
                transaction.data,
                transaction.value,
                ""
            );
            emit WithdrawERC1155(
                msg.sender,
                transaction.to,
                transaction.tokenAddress,
                transaction.data,
                transaction.value
            );
        } else if (transaction.txType == TransactionType.AddOwner) {
            require(owners.length < 10, "Max 10 owners allowed");
            require(!isOwner[transaction.to], "Address is already an owner");
            require(
                transaction.to.code.length == 0 || isEIP7702(transaction.to),
                "New owner must be EOA or EIP-7702 upgraded EOA"
            );
            isOwner[transaction.to] = true;
            owners.push(transaction.to);
            emit OwnerAdded(transaction.to);
        } else if (transaction.txType == TransactionType.RemoveOwner) {
            require(isOwner[transaction.to], "Not an owner");
            require(owners.length > 1, "Cannot remove the last owner");
            isOwner[transaction.to] = false;
            for (uint256 i = 0; i < owners.length; i++) {
                if (owners[i] == transaction.to) {
                    owners[i] = owners[owners.length - 1];
                    owners.pop();
                    break;
                }
            }
            if (requiredSignatures > owners.length) {
                requiredSignatures = owners.length;
            }
            emit OwnerRemoved(transaction.to);
        } else if (
            transaction.txType == TransactionType.ChangeRequiredSignatures
        ) {
            uint256 newRequired = transaction.data;
            require(
                newRequired > 0 && newRequired <= owners.length,
                "Invalid number of required signatures"
            );
            requiredSignatures = newRequired;
            emit RequiredSignaturesChanged(newRequired);
        } else {
            revert("Invalid transaction type");
        }

        transaction.executed = true;
        emit ExecuteTransaction(msg.sender, _txIndex);
    }

    function revokeConfirmation(
        uint256 _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(
            transaction.isConfirmed[msg.sender],
            "Transaction not confirmed"
        );
        transaction.isConfirmed[msg.sender] = false;
        transaction.confirmations -= 1;
        emit RevokeConfirmation(msg.sender, _txIndex);
    }

    function cancelTransaction(
        uint256 _txIndex
    ) public onlyOwner txExists(_txIndex) notExecuted(_txIndex) {
        Transaction storage transaction = transactions[_txIndex];
        require(
            transaction.confirmations < requiredSignatures,
            "Cannot cancel fully confirmed tx"
        );
        require(
            cancelVotes[_txIndex] < requiredSignatures,
            "Already enough votes to cancel"
        );
        require(
            !hasVotedCancel[_txIndex][msg.sender],
            "Already voted to cancel"
        );

        hasVotedCancel[_txIndex][msg.sender] = true;
        cancelVotes[_txIndex] += 1;
        if (cancelVotes[_txIndex] >= requiredSignatures) {
            for (uint256 i = 0; i < owners.length; i++) {
                transaction.isConfirmed[owners[i]] = false;
                hasVotedCancel[_txIndex][owners[i]] = false;
            }
            transaction.confirmations = 0;
            cancelVotes[_txIndex] = 0;
        }
        emit CancelTransaction(msg.sender, _txIndex);
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(
        uint256 _txIndex
    )
        public
        view
        returns (
            address to,
            uint256 value,
            bool executed,
            uint256 confirmations,
            uint256 createdAt,
            address tokenAddress,
            uint256 txRequiredSignatures,
            TransactionType txType,
            uint256 data
        )
    {
        Transaction storage transaction = transactions[_txIndex];
        return (
            transaction.to,
            transaction.value,
            transaction.executed,
            transaction.confirmations,
            transaction.createdAt,
            transaction.tokenAddress,
            transaction.requiredSignatures,
            transaction.txType,
            transaction.data
        );
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }
}
