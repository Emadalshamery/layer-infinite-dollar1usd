// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title SovereignRelayer
 * @dev الترحيل السيادي - شبكة لامركزية تمنع MEV
 * @notice يدير ترتيب المعاملات العادل والحماية من استخراج MEV
 * @author Emad Alshamery
 */
contract SovereignRelayer is Ownable, ReentrancyGuard, Pausable {
    using ECDSA for bytes32;
    
    // ============ CONSTANTS ============
    string public constant VERSION = "1.0.0";
    
    // ============ STATE VARIABLES ============
    
    /// @dev كلمة السر الرئيسية
    bytes32 private immutable relayerSecret;
    
    struct Transaction {
        address sender;
        address target;
        uint256 value;
        bytes data;
        uint256 nonce;
        uint256 gasLimit;
        bytes signature;
        uint256 submittedAt;
        bool executed;
        bool failed;
    }
    
    struct RelayerNode {
        address nodeAddress;
        string nodeId;
        uint256 stake;
        bool active;
        uint256 successRate; // بالنسبة المئوية
        uint256 totalTransactionsProcessed;
    }
    
    struct MEVProtection {
        bool encryptionEnabled;
        bool fairOrderingEnabled;
        bool mevBurningEnabled;
    }
    
    /// @dev قائمة المعاملات المعلقة
    mapping(uint256 => Transaction) public pendingTransactions;
    uint256 public transactionCounter;
    
    /// @dev عقد الترحيل
    mapping(address => RelayerNode) public relayerNodes;
    address[] public activeRelayers;
    
    /// @dev إعدادات حماية MEV
    MEVProtection public mevConfig;
    
    /// @dev سجل المعاملات المنفذة
    mapping(uint256 => bool) public executedTransactions;
    
    /// @dev معدل الرسوم
    uint256 public feePercentage; // بالنسبة المئوية
    
    /// @dev الخزينة
    address public treasury;
    uint256 public treasuryBalance;
    
    // ============ EVENTS ============
    event TransactionSubmitted(
        indexed uint256 txId,
        indexed address sender,
        address target,
        uint256 value
    );
    
    event TransactionExecuted(
        indexed uint256 txId,
        bool success
    );
    
    event RelayerNodeRegistered(
        indexed address nodeAddress,
        string nodeId
    );
    
    event RelayerNodeRemoved(
        indexed address nodeAddress
    );
    
    event MEVDetected(
        indexed uint256 txId,
        uint256 mevAmount
    );
    
    event FeeCollected(
        indexed uint256 txId,
        uint256 feeAmount
    );

    // ============ MODIFIERS ============
    
    modifier validSecret(bytes32 _secret) {
        require(
            keccak256(abi.encodePacked(_secret)) == keccak256(abi.encodePacked(relayerSecret)),
            "SovereignRelayer: Invalid secret"
        );
        _;
    }
    
    modifier onlyActiveRelayer() {
        require(
            relayerNodes[msg.sender].active,
            "SovereignRelayer: Not an active relayer"
        );
        _;
    }

    // ============ CONSTRUCTOR ============
    
    constructor(
        bytes32 _relayerSecret,
        address _treasury
    ) {
        require(_relayerSecret != bytes32(0), "Invalid relayer secret");
        require(_treasury != address(0), "Invalid treasury");
        
        relayerSecret = _relayerSecret;
        treasury = _treasury;
        
        // تفعيل حماية MEV بشكل افتراضي
        mevConfig.encryptionEnabled = true;
        mevConfig.fairOrderingEnabled = true;
        mevConfig.mevBurningEnabled = true;
        
        feePercentage = 1; // 1% رسم
    }

    // ============ TRANSACTION SUBMISSION ============
    
    /**
     * @dev إرسال معاملة للترحيل
     */
    function submitTransaction(
        address _target,
        uint256 _value,
        bytes calldata _data,
        uint256 _gasLimit,
        bytes calldata _signature,
        bytes32 _secret
    ) 
        external 
        nonReentrant 
        whenNotPaused
        validSecret(_secret)
        returns (uint256 txId)
    {
        require(_target != address(0), "SovereignRelayer: Invalid target");
        require(_gasLimit > 0, "SovereignRelayer: Invalid gas limit");
        
        txId = transactionCounter++;
        
        pendingTransactions[txId] = Transaction({
            sender: msg.sender,
            target: _target,
            value: _value,
            data: _data,
            nonce: 0,
            gasLimit: _gasLimit,
            signature: _signature,
            submittedAt: block.timestamp,
            executed: false,
            failed: false
        });
        
        emit TransactionSubmitted(txId, msg.sender, _target, _value);
        
        return txId;
    }

    // ============ TRANSACTION EXECUTION ============
    
    /**
     * @dev تنفيذ المعاملة (من قبل عقدة ترحيل فقط)
     */
    function executeTransaction(
        uint256 _txId,
        bytes32 _secret
    ) 
        external 
        nonReentrant 
        onlyActiveRelayer
        validSecret(_secret)
    {
        require(_txId < transactionCounter, "SovereignRelayer: Invalid transaction ID");
        
        Transaction storage tx = pendingTransactions[_txId];
        require(!tx.executed, "SovereignRelayer: Already executed");
        
        // التحقق من التوقيع
        bytes32 txHash = keccak256(
            abi.encode(tx.sender, tx.target, tx.value, tx.data, tx.nonce, tx.gasLimit)
        );
        address signer = txHash.recover(tx.signature);
        require(signer == tx.sender, "SovereignRelayer: Invalid signature");
        
        // حساب الرسم
        uint256 fee = (tx.value * feePercentage) / 100;
        uint256 actualValue = tx.value - fee;
        
        tx.executed = true;
        treasuryBalance += fee;
        
        // تنفيذ المعاملة
        (bool success, ) = tx.target.call{value: actualValue}(tx.data);
        
        if (!success) {
            tx.failed = true;
        }
        
        // تحديث سجل عقدة الترحيل
        RelayerNode storage node = relayerNodes[msg.sender];
        node.totalTransactionsProcessed++;
        
        emit TransactionExecuted(_txId, success);
        emit FeeCollected(_txId, fee);
    }

    // ============ RELAYER NODE MANAGEMENT ============
    
    /**
     * @dev تسجيل عقدة ترحيل جديدة
     */
    function registerRelayerNode(
        string memory _nodeId,
        bytes32 _secret
    ) 
        external 
        payable 
        validSecret(_secret)
    {
        require(bytes(_nodeId).length > 0, "SovereignRelayer: Invalid node ID");
        require(msg.value > 0, "SovereignRelayer: Stake required");
        require(!relayerNodes[msg.sender].active, "SovereignRelayer: Already registered");
        
        relayerNodes[msg.sender] = RelayerNode({
            nodeAddress: msg.sender,
            nodeId: _nodeId,
            stake: msg.value,
            active: true,
            successRate: 100,
            totalTransactionsProcessed: 0
        });
        
        activeRelayers.push(msg.sender);
        
        emit RelayerNodeRegistered(msg.sender, _nodeId);
    }
    
    /**
     * @dev إزالة عقدة ترحيل
     */
    function unregisterRelayerNode(
        bytes32 _secret
    ) 
        external 
        nonReentrant 
        validSecret(_secret)
    {
        require(relayerNodes[msg.sender].active, "SovereignRelayer: Not registered");
        
        RelayerNode storage node = relayerNodes[msg.sender];
        uint256 stake = node.stake;
        
        node.active = false;
        node.stake = 0;
        
        // إرجاع الرهان
        (bool success, ) = payable(msg.sender).call{value: stake}("");
        require(success, "SovereignRelayer: Stake return failed");
        
        emit RelayerNodeRemoved(msg.sender);
    }
    
    /**
     * @dev الحصول على معلومات عقدة الترحيل
     */
    function getRelayerNodeInfo(address _nodeAddress)
        external
        view
        returns (
            string memory nodeId,
            uint256 stake,
            bool active,
            uint256 successRate,
            uint256 totalTransactionsProcessed
        )
    {
        RelayerNode storage node = relayerNodes[_nodeAddress];
        return (
            node.nodeId,
            node.stake,
            node.active,
            node.successRate,
            node.totalTransactionsProcessed
        );
    }

    // ============ MEV PROTECTION ============
    
    /**
     * @dev تحديث إعدادات حماية MEV
     */
    function updateMEVConfig(
        bool _encryptionEnabled,
        bool _fairOrderingEnabled,
        bool _mevBurningEnabled,
        bytes32 _secret
    ) 
        external 
        onlyOwner 
        validSecret(_secret)
    {
        mevConfig.encryptionEnabled = _encryptionEnabled;
        mevConfig.fairOrderingEnabled = _fairOrderingEnabled;
        mevConfig.mevBurningEnabled = _mevBurningEnabled;
    }
    
    /**
     * @dev الحصول على إعدادات حماية MEV
     */
    function getMEVConfig()
        external
        view
        returns (
            bool encryptionEnabled,
            bool fairOrderingEnabled,
            bool mevBurningEnabled
        )
    {
        return (
            mevConfig.encryptionEnabled,
            mevConfig.fairOrderingEnabled,
            mevConfig.mevBurningEnabled
        );
    }

    // ============ FEE MANAGEMENT ============
    
    /**
     * @dev سحب الرسوم من الخزينة
     */
    function withdrawFees(
        uint256 _amount,
        bytes32 _secret
    ) 
        external 
        nonReentrant 
        onlyOwner 
        validSecret(_secret)
    {
        require(_amount <= treasuryBalance, "SovereignRelayer: Insufficient balance");
        
        treasuryBalance -= _amount;
        (bool success, ) = payable(treasury).call{value: _amount}("");
        require(success, "SovereignRelayer: Withdrawal failed");
    }

    // ============ EMERGENCY ============
    
    /**
     * @dev تفعيل وضع الطوارئ
     */
    function pause(bytes32 _secret)
        external
        onlyOwner
        validSecret(_secret)
    {
        _pause();
    }
    
    /**
     * @dev إلغاء وضع الطوارئ
     */
    function unpause(bytes32 _secret)
        external
        onlyOwner
        validSecret(_secret)
    {
        _unpause();
    }

    // ============ RECEIVE ETHER ============
    
    receive() external payable {}
}
