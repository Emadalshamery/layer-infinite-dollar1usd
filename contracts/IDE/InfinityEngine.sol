// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/**
 * @title InfinityEngine
 * @dev محرك التفويض الإنفينيتي - الركيزة الأساسية للأمان
 * @notice يدير التفويض الآمن، الاستعادة الطارئة، والتوقيع متعدد المستويات
 * @author Emad Alshamery
 */
contract InfinityEngine is Ownable, ReentrancyGuard, Pausable, EIP712 {
    using ECDSA for bytes32;

    // ============ CONSTANTS ============
    /// @notice نسخة العقد
    string public constant VERSION = "1.0.0";
    
    /// @notice معرف النوع للتفويض
    bytes32 private constant DELEGATION_TYPEHASH =
        keccak256(
            "Delegation(address user,address agent,uint256 limit,uint256 nonce,uint256 expiresAt,bytes conditions)"
        );

    /// @notice معرف النوع للاستعادة
    bytes32 private constant RECOVERY_TYPEHASH =
        keccak256("Recovery(address user,uint256 nonce,uint256 timestamp)");

    // ============ STATE VARIABLES ============
    
    /// @dev كلمة السر الرئيسية (الملح) - مشفرة بـ SHA-256
    bytes32 private immutable masterSecret;
    
    /// @dev كلمات سر إدارية متعددة - لا تقبل التعديل
    bytes32[] private immutable adminSecrets;
    
    /// @dev المفاتيح الخاصة المشفرة
    mapping(address => bytes32) private encryptedPrivateKeys;
    
    struct Delegation {
        address agent;
        uint256 limit;
        uint256 nonce;
        uint256 expiresAt;
        bytes conditions;
        bool active;
        uint256 createdAt;
        uint256 usedAmount;
    }

    struct RecoveryRequest {
        address user;
        uint256 amount;
        uint256 requestedAt;
        bool approved;
        uint8 approvalsCount;
        mapping(address => bool) approvers;
    }

    struct ProtocolConfig {
        bool emergencyPause;
        uint256 maxDelegationLimit;
        uint256 maxRecoveryAmount;
        uint8 requiredApprovalsForRecovery;
        bool whitelistRequired;
    }

    /// @dev قاموس التفويضات
    mapping(address => mapping(address => Delegation)) public delegations;
    
    /// @dev طلبات الاستعادة
    mapping(uint256 => RecoveryRequest) public recoveryRequests;
    mapping(address => uint256[]) public userRecoveryRequests;
    
    /// @dev السجل الأسود (محافظ موثوقة فقط)
    mapping(address => bool) public whitelist;
    
    /// @dev السجل الأسود (محافظ محظورة)
    mapping(address => bool) public blacklist;
    
    /// @dev الموافقون على الاستعادة
    address[] private recoveryApprovers;
    
    /// @dev إعدادات البروتوكول
    ProtocolConfig public config;
    
    /// @dev معرف الاستعادة الفريد
    uint256 private recoveryRequestCounter;
    
    /// @dev عداد Nonce للمستخدمين
    mapping(address => uint256) public nonces;
    
    /// @dev سجل الأنشطة (للتحقق من المحاولات المريبة)
    mapping(address => ActivityLog[]) public activityLog;
    
    struct ActivityLog {
        uint256 timestamp;
        string action;
        address relatedAddress;
        uint256 amount;
        bool success;
    }

    // ============ EVENTS ============
    event DelegationActivated(
        indexed address user,
        indexed address agent,
        uint256 limit,
        uint256 expiresAt
    );
    
    event DelegationRevoked(
        indexed address user,
        indexed address agent
    );
    
    event RecoveryRequested(
        indexed address user,
        uint256 indexed recoveryId,
        uint256 amount
    );
    
    event RecoveryApproved(
        uint256 indexed recoveryId,
        indexed address approver
    );
    
    event RecoveryExecuted(
        indexed address user,
        uint256 indexed recoveryId,
        uint256 amount
    );
    
    event EmergencyRecoveryTriggered(
        indexed address user,
        uint256 amount
    );
    
    event ActivityLogged(
        indexed address user,
        string action,
        bool success
    );
    
    event WhitelistUpdated(
        indexed address user,
        bool status
    );
    
    event BlacklistUpdated(
        indexed address user,
        bool status
    );
    
    event ProtocolConfigUpdated(
        uint256 maxDelegationLimit,
        uint8 requiredApprovals
    );

    // ============ MODIFIERS ============
    
    modifier onlyWhitelisted() {
        require(
            !config.whitelistRequired || whitelist[msg.sender],
            "InfinityEngine: Not whitelisted"
        );
        _;
    }
    
    modifier notBlacklisted(address _user) {
        require(
            !blacklist[_user],
            "InfinityEngine: Address is blacklisted"
        );
        _;
    }
    
    modifier validSecretKey(bytes32 _secretKey) {
        require(
            verifySecret(_secretKey),
            "InfinityEngine: Invalid secret key"
        );
        _;
    }
    
    modifier notPausedByEmergency() {
        require(
            !config.emergencyPause,
            "InfinityEngine: Emergency pause active"
        );
        _;
    }

    // ============ CONSTRUCTOR ============
    
    constructor(
        bytes32 _masterSecret,
        bytes32[] memory _adminSecrets,
        address[] memory _initialApprovers
    ) EIP712("Layer∞", "1.0.0") {
        require(_masterSecret != bytes32(0), "Invalid master secret");
        require(_adminSecrets.length > 0, "At least one admin secret required");
        require(_initialApprovers.length >= 2, "At least 2 approvers required");
        
        // تخزين كلمات السر بشكل آمن
        masterSecret = _masterSecret;
        
        // تخزين كلمات السر الإدارية كـ immutable
        for (uint256 i = 0; i < _adminSecrets.length; i++) {
            require(_adminSecrets[i] != bytes32(0), "Invalid admin secret");
            adminSecrets.push(_adminSecrets[i]);
        }
        
        // تعيين الموافقون الأوليون
        for (uint256 i = 0; i < _initialApprovers.length; i++) {
            require(_initialApprovers[i] != address(0), "Invalid approver");
            recoveryApprovers.push(_initialApprovers[i]);
            whitelist[_initialApprovers[i]] = true;
        }
        
        // إعدادات افتراضية
        config.maxDelegationLimit = 1000 ether;
        config.maxRecoveryAmount = 10000 ether;
        config.requiredApprovalsForRecovery = 2;
        config.whitelistRequired = true;
        config.emergencyPause = false;
    }

    // ============ SECRET VERIFICATION ============
    
    /**
     * @dev تحقق من كلمة السر
     * @param _secretKey كلمة السر المراد التحقق منها
     * @return صحيح إذا كانت كلمة السر صحيحة
     */
    function verifySecret(bytes32 _secretKey) public view returns (bool) {
        // تحقق من كلمة السر الرئيسية
        if (keccak256(abi.encodePacked(_secretKey)) == keccak256(abi.encodePacked(masterSecret))) {
            return true;
        }
        
        // تحقق من كلمات السر الإدارية
        for (uint256 i = 0; i < adminSecrets.length; i++) {
            if (keccak256(abi.encodePacked(_secretKey)) == keccak256(abi.encodePacked(adminSecrets[i]))) {
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * @dev الحصول على عدد كلمات السر الإدارية
     */
    function getAdminSecretsCount() external view returns (uint256) {
        return adminSecrets.length;
    }

    // ============ DELEGATION FUNCTIONS ============
    
    /**
     * @dev تفعيل التفويض الآمن
     * @param _agent عنوان الوكيل
     * @param _limit حد التفويض
     * @param _duration مدة التفويض بالثواني
     * @param _conditions شروط التفويض
     * @param _secretKey كلمة السر للتحقق
     */
    function delegateTo(
        address _agent,
        uint256 _limit,
        uint256 _duration,
        bytes calldata _conditions,
        bytes32 _secretKey
    ) 
        external 
        nonReentrant 
        notPausedByEmergency 
        validSecretKey(_secretKey)
        onlyWhitelisted
        notBlacklisted(msg.sender)
    {
        require(_agent != address(0), "InfinityEngine: Invalid agent address");
        require(_limit > 0, "InfinityEngine: Limit must be > 0");
        require(_limit <= config.maxDelegationLimit, "InfinityEngine: Limit exceeds maximum");
        require(_duration > 0, "InfinityEngine: Duration must be > 0");
        require(_duration <= 365 days, "InfinityEngine: Duration too long");
        require(!blacklist[_agent], "InfinityEngine: Agent is blacklisted");
        
        uint256 expiresAt = block.timestamp + _duration;
        
        delegations[msg.sender][_agent] = Delegation({
            agent: _agent,
            limit: _limit,
            nonce: nonces[msg.sender]++,
            expiresAt: expiresAt,
            conditions: _conditions,
            active: true,
            createdAt: block.timestamp,
            usedAmount: 0
        });
        
        logActivity(msg.sender, "DELEGATE_ACTIVATED", _agent, _limit, true);
        emit DelegationActivated(msg.sender, _agent, _limit, expiresAt);
    }
    
    /**
     * @dev إلغاء التفويض
     * @param _agent عنوان الوكيل
     * @param _secretKey كلمة السر للتحقق
     */
    function revokeDelegation(
        address _agent,
        bytes32 _secretKey
    ) 
        external 
        nonReentrant 
        validSecretKey(_secretKey)
    {
        require(_agent != address(0), "InfinityEngine: Invalid agent address");
        require(delegations[msg.sender][_agent].active, "InfinityEngine: No active delegation");
        
        delegations[msg.sender][_agent].active = false;
        
        logActivity(msg.sender, "DELEGATE_REVOKED", _agent, 0, true);
        emit DelegationRevoked(msg.sender, _agent);
    }
    
    /**
     * @dev التحقق من صلاحية التفويض
     */
    function isDelegationValid(
        address _user,
        address _agent
    ) 
        external 
        view 
        returns (bool)
    {
        Delegation storage deleg = delegations[_user][_agent];
        return (
            deleg.active &&
            block.timestamp <= deleg.expiresAt &&
            deleg.usedAmount < deleg.limit
        );
    }

    // ============ RECOVERY FUNCTIONS ============
    
    /**
     * @dev طلب استعادة الأصول
     * @param _amount المبلغ المطلوب استعادته
     * @param _secretKey كلمة السر للتحقق
     */
    function requestRecovery(
        uint256 _amount,
        bytes32 _secretKey
    ) 
        external 
        nonReentrant 
        validSecretKey(_secretKey)
        notBlacklisted(msg.sender)
    {
        require(_amount > 0, "InfinityEngine: Amount must be > 0");
        require(_amount <= config.maxRecoveryAmount, "InfinityEngine: Amount exceeds maximum");
        
        uint256 recoveryId = recoveryRequestCounter++;
        
        RecoveryRequest storage req = recoveryRequests[recoveryId];
        req.user = msg.sender;
        req.amount = _amount;
        req.requestedAt = block.timestamp;
        req.approved = false;
        req.approvalsCount = 0;
        
        userRecoveryRequests[msg.sender].push(recoveryId);
        
        logActivity(msg.sender, "RECOVERY_REQUESTED", address(0), _amount, true);
        emit RecoveryRequested(msg.sender, recoveryId, _amount);
    }
    
    /**
     * @dev الموافقة على طلب الاستعادة (من الموافقين المأذونين فقط)
     * @param _recoveryId معرف طلب الاستعادة
     * @param _secretKey كلمة السر للتحقق
     */
    function approveRecovery(
        uint256 _recoveryId,
        bytes32 _secretKey
    ) 
        external 
        validSecretKey(_secretKey)
    {
        require(_recoveryId < recoveryRequestCounter, "InfinityEngine: Invalid recovery ID");
        
        bool isApprover = false;
        for (uint256 i = 0; i < recoveryApprovers.length; i++) {
            if (recoveryApprovers[i] == msg.sender) {
                isApprover = true;
                break;
            }
        }
        require(isApprover, "InfinityEngine: Not an approved signer");
        
        RecoveryRequest storage req = recoveryRequests[_recoveryId];
        require(!req.approved, "InfinityEngine: Already approved");
        require(!req.approvers[msg.sender], "InfinityEngine: Already voted");
        
        req.approvers[msg.sender] = true;
        req.approvalsCount++;
        
        if (req.approvalsCount >= config.requiredApprovalsForRecovery) {
            req.approved = true;
        }
        
        logActivity(msg.sender, "RECOVERY_APPROVED", req.user, req.amount, true);
        emit RecoveryApproved(_recoveryId, msg.sender);
    }
    
    /**
     * @dev تنفيذ الاستعادة (بعد الحصول على الموافقات الكافية)
     * @param _recoveryId معرف طلب الاستعادة
     * @param _secretKey كلمة السر للتحقق
     */
    function executeRecovery(
        uint256 _recoveryId,
        bytes32 _secretKey
    ) 
        external 
        nonReentrant 
        validSecretKey(_secretKey)
    {
        require(_recoveryId < recoveryRequestCounter, "InfinityEngine: Invalid recovery ID");
        
        RecoveryRequest storage req = recoveryRequests[_recoveryId];
        require(req.approved, "InfinityEngine: Not approved yet");
        require(req.user != address(0), "InfinityEngine: Invalid user");
        
        address user = req.user;
        uint256 amount = req.amount;
        
        // منع الهجمات من النوع Re-entrancy
        req.approved = false;
        req.amount = 0;
        
        (bool success, ) = payable(user).call{value: amount}("");
        require(success, "InfinityEngine: Transfer failed");
        
        logActivity(user, "RECOVERY_EXECUTED", address(0), amount, true);
        emit RecoveryExecuted(user, _recoveryId, amount);
    }
    
    /**
     * @dev استعادة طوارئ (مباشرة من قبل الموافقين)
     * @param _user عنوان المستخدم
     * @param _secretKey كلمة السر للتحقق
     */
    function emergencyRecovery(
        address _user,
        bytes32 _secretKey
    ) 
        external 
        nonReentrant 
        validSecretKey(_secretKey)
        onlyOwner
    {
        require(_user != address(0), "InfinityEngine: Invalid user address");
        
        uint256 balance = address(this).balance;
        require(balance > 0, "InfinityEngine: No balance to recover");
        
        (bool success, ) = payable(_user).call{value: balance}("");
        require(success, "InfinityEngine: Emergency recovery failed");
        
        logActivity(_user, "EMERGENCY_RECOVERY", address(0), balance, true);
        emit EmergencyRecoveryTriggered(_user, balance);
    }

    // ============ ACTIVITY LOGGING ============
    
    /**
     * @dev تسجيل النشاط
     */
    function logActivity(
        address _user,
        string memory _action,
        address _related,
        uint256 _amount,
        bool _success
    ) 
        private 
    {
        activityLog[_user].push(
            ActivityLog({
                timestamp: block.timestamp,
                action: _action,
                relatedAddress: _related,
                amount: _amount,
                success: _success
            })
        );
        
        emit ActivityLogged(_user, _action, _success);
    }
    
    /**
     * @dev الحصول على سجل الأنشطة
     */
    function getActivityLog(address _user, uint256 _limit)
        external
        view
        returns (ActivityLog[] memory)
    {
        uint256 length = activityLog[_user].length;
        uint256 count = _limit < length ? _limit : length;
        
        ActivityLog[] memory logs = new ActivityLog[](count);
        
        for (uint256 i = 0; i < count; i++) {
            logs[i] = activityLog[_user][length - count + i];
        }
        
        return logs;
    }

    // ============ WHITELIST & BLACKLIST ============
    
    /**
     * @dev إضافة عنوان إلى القائمة البيضاء
     */
    function addToWhitelist(
        address _user,
        bytes32 _secretKey
    ) 
        external 
        validSecretKey(_secretKey)
        onlyOwner
    {
        require(_user != address(0), "InfinityEngine: Invalid address");
        whitelist[_user] = true;
        emit WhitelistUpdated(_user, true);
    }
    
    /**
     * @dev إزالة عنوان من القائمة البيضاء
     */
    function removeFromWhitelist(
        address _user,
        bytes32 _secretKey
    ) 
        external 
        validSecretKey(_secretKey)
        onlyOwner
    {
        require(_user != address(0), "InfinityEngine: Invalid address");
        whitelist[_user] = false;
        emit WhitelistUpdated(_user, false);
    }
    
    /**
     * @dev إضافة عنوان إلى القائمة السوداء
     */
    function addToBlacklist(
        address _user,
        bytes32 _secretKey
    ) 
        external 
        validSecretKey(_secretKey)
        onlyOwner
    {
        require(_user != address(0), "InfinityEngine: Invalid address");
        blacklist[_user] = true;
        emit BlacklistUpdated(_user, true);
    }
    
    /**
     * @dev إزالة عنوان من القائمة السوداء
     */
    function removeFromBlacklist(
        address _user,
        bytes32 _secretKey
    ) 
        external 
        validSecretKey(_secretKey)
        onlyOwner
    {
        require(_user != address(0), "InfinityEngine: Invalid address");
        blacklist[_user] = false;
        emit BlacklistUpdated(_user, false);
    }

    // ============ PROTOCOL CONFIG ============
    
    /**
     * @dev تحديث إعدادات البروتوكول
     */
    function updateConfig(
        uint256 _maxDelegationLimit,
        uint256 _maxRecoveryAmount,
        uint8 _requiredApprovals,
        bytes32 _secretKey
    ) 
        external 
        validSecretKey(_secretKey)
        onlyOwner
    {
        require(_maxDelegationLimit > 0, "InfinityEngine: Invalid limit");
        require(_maxRecoveryAmount > 0, "InfinityEngine: Invalid amount");
        require(_requiredApprovals >= 2, "InfinityEngine: At least 2 approvals required");
        
        config.maxDelegationLimit = _maxDelegationLimit;
        config.maxRecoveryAmount = _maxRecoveryAmount;
        config.requiredApprovalsForRecovery = _requiredApprovals;
        
        emit ProtocolConfigUpdated(_maxDelegationLimit, _requiredApprovals);
    }
    
    /**
     * @dev تفعيل وضع الطوارئ
     */
    function setEmergencyPause(
        bool _pause,
        bytes32 _secretKey
    ) 
        external 
        validSecretKey(_secretKey)
        onlyOwner
    {
        config.emergencyPause = _pause;
    }

    // ============ RECEIVE ETHER ============
    
    receive() external payable {}
    
    fallback() external payable {}
}
