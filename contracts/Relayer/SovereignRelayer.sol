// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title SovereignRelayer
 * @dev الترحيل السيادي - شبكة لامركزية تمنع MEV
 * @author Emad Alshamery
 */
contract SovereignRelayer is Ownable, ReentrancyGuard, Pausable {
    using ECDSA for bytes32;
    
    string public constant VERSION = "1.1.0";
    
    struct Transaction {
        address sender;
        address target;
        uint256 value;
        bytes data;
        uint256 nonce;
        uint256 gasLimit;
        bytes signature;
        bool executed;
        bool failed;
    }
    
    struct RelayerNode {
        address nodeAddress;
        string nodeId;
        uint256 stake;
        bool active;
        uint256 totalTransactionsProcessed;
    }

    // تعقب الـ Nonce لكل مستخدم لمنع Replay Attacks
    mapping(address => uint256) public userNonces;
    
    mapping(uint256 => Transaction) public pendingTransactions;
    uint256 public transactionCounter;
    
    mapping(address => RelayerNode) public relayerNodes;
    address[] public activeRelayers;
    
    uint256 public feePercentage; 
    address public treasury;
    uint256 public treasuryBalance;

    event TransactionSubmitted(indexed uint256 txId, indexed address sender, address target, uint256 value);
    event TransactionExecuted(indexed uint256 txId, bool success);
    event RelayerNodeRegistered(indexed address nodeAddress, string nodeId);

    modifier onlyActiveRelayer() {
        require(relayerNodes[msg.sender].active, "SovereignRelayer: Not an active relayer");
        _;
    }

    constructor(address _treasury) {
        require(_treasury != address(0), "Invalid treasury");
        treasury = _treasury;
        feePercentage = 1; // 1% رسم
    }

    /**
     * @dev إرسال المعاملة مع التحقق من الـ Nonce الخاص بالمستخدم
     */
    function submitTransaction(
        address _target,
        uint256 _value,
        bytes calldata _data,
        uint256 _gasLimit,
        bytes calldata _signature
    ) external nonReentrant whenNotPaused returns (uint256 txId) {
        require(_target != address(0), "SovereignRelayer: Invalid target");
        
        txId = transactionCounter++;
        
        pendingTransactions[txId] = Transaction({
            sender: msg.sender,
            target: _target,
            value: _value,
            data: _data,
            nonce: userNonces[msg.sender]++,
            gasLimit: _gasLimit,
            signature: _signature,
            executed: false,
            failed: false
        });
        
        emit TransactionSubmitted(txId, msg.sender, _target, _value);
    }

    /**
     * @dev تنفيذ المعاملة من قبل العقدة، مع التحقق من التوقيع و الـ ChainID
     */
    function executeTransaction(uint256 _txId) 
        external 
        nonReentrant 
        onlyActiveRelayer
    {
        require(_txId < transactionCounter, "SovereignRelayer: Invalid ID");
        Transaction storage _tx = pendingTransactions[_txId];
        require(!_tx.executed, "SovereignRelayer: Already executed");
        
        // بناء الهش للتحقق من سلامة البيانات وربطه بالشبكة الحالية
        bytes32 txHash = keccak256(
            abi.encode(block.chainid, _tx.sender, _tx.target, _tx.value, _tx.data, _tx.nonce, _tx.gasLimit)
        );
        
        address signer = txHash.toEthSignedMessageHash().recover(_tx.signature);
        require(signer == _tx.sender, "SovereignRelayer: Invalid signature");
        
        uint256 fee = (_tx.value * feePercentage) / 100;
        uint256 actualValue = _tx.value - fee;
        
        _tx.executed = true;
        treasuryBalance += fee;
        
        (bool success, ) = _tx.target.call{value: actualValue, gas: _tx.gasLimit}(_tx.data);
        
        if (!success) _tx.failed = true;
        
        relayerNodes[msg.sender].totalTransactionsProcessed++;
        emit TransactionExecuted(_txId, success);
    }

    // إدارة العقد والرسوم (الخاصة بالمالك)
    function registerRelayerNode(string memory _nodeId) external payable {
        require(msg.value > 0, "Stake required");
        relayerNodes[msg.sender] = RelayerNode(msg.sender, _nodeId, msg.value, true, 0);
        activeRelayers.push(msg.sender);
        emit RelayerNodeRegistered(msg.sender, _nodeId);
    }
}
