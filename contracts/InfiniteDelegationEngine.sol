// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title InfiniteDelegationEngine (IDE) - Dollar1usd Protocol
 * @dev يسمح بالتفويض الآمن مرن الحالات عبر السلاسل وإدارة مسارات المعاملات مع دعم كامل لآليات EIP-7702 وحماية MEV.
 */
contract InfiniteDelegationEngine is ReentrancyGuard {
    using ECDSA for bytes32;

    // هيكل بيانات التفويض
    struct Delegation {
        address delegatee;    // الجهة المفوضة (البوت أو الوكيل)
        uint256 chainId;      // معرف السلسلة المستهدفة (عبر السلاسل)
        uint256 maxGasPrice;  // الحد الأقصى لسعر الغاز المسموح به لحماية MEV
        uint256 nonce;        // كود الحماية ضد إعادة تشغيل المعاملات (Replay Attack)
        bool isActive;        // حالة التفويض
    }

    // تعيين من عنوان المستخدم (Owner) إلى معرف التفويض (Delegation ID)
    mapping(address => mapping(bytes32 => Delegation)) public delegations;
    
    // تتبع الـ Nonce الخاص بكل مستخدم لحماية التوقيعات الديناميكية
    mapping(address => uint256) public userNonces;

    // الأحداث (Events) لمزامنة الحالات خارج السلسلة
    event DelegationCreated(address indexed owner, address indexed delegatee, uint256 chainId, bytes32 delegationId);
    event DelegationRevoked(address indexed owner, uint256 chainId, bytes32 delegationId);
    event ExecutionTriggered(address indexed owner, address indexed delegatee, uint256 chainId);

    // غطاء الحماية للاستدعاء الطارئ
    modifier onlyDclOwner(bytes32 delegationId) {
        require(delegations[msg.sender][delegationId].isActive, "IDE: Delegation is not active or not owned");
        _;
    }

    /**
     * @dev توليد معرف التفويض ا��فريد (Delegation ID)
     */
    function getDelegationId(address _owner, uint256 _chainId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_owner, _chainId));
    }

    /**
     * @dev إنشاء تفويض جديد آمن وغير حاضن
     */
    function createDelegation(
        address _delegatee,
        uint256 _chainId,
        uint256 _maxGasPrice
    ) external {
        require(_delegatee != address(0), "IDE: Invalid delegatee address");
        bytes32 delegationId = getDelegationId(msg.sender, _chainId);
        require(!delegations[msg.sender][delegationId].isActive, "IDE: Delegation already exists and is active");
        
        delegations[msg.sender][delegationId] = Delegation({
            delegatee: _delegatee,
            chainId: _chainId,
            maxGasPrice: _maxGasPrice,
            nonce: userNonces[msg.sender],
            isActive: true
        });

        emit DelegationCreated(msg.sender, _delegatee, _chainId, delegationId);
    }

    /**
     * @dev نظام التراجع الطارئ (Emergency Revocation) - سحب التفويض فوراً
     */
    function revokeDelegation(uint256 _chainId) external {
        bytes32 delegationId = getDelegationId(msg.sender, _chainId);
        require(delegations[msg.sender][delegationId].isActive, "IDE: Delegation already inactive");
        
        delegations[msg.sender][delegationId].isActive = false;
        userNonces[msg.sender]++; // زيادة الـ Nonce لتعطيل أي توقيعات قديمة خارج السلسلة فوراً
        
        emit DelegationRevoked(msg.sender, _chainId, delegationId);
    }

    /**
     * @dev التحقق من شروط الغاز والتوقيع، ثم تنفيذ المعاملة المستهدفة لحماية الحساب من الـ MEV (متوافق مع EIP-7702)
     */
    function verifyAndExecute(
        address _owner,
        uint256 _chainId,
        address _target,
        bytes calldata _payload,
        bytes calldata _signature
    ) external payable nonReentrant returns (bytes memory) {
        bytes32 delegationId = getDelegationId(_owner, _chainId);
        Delegation memory auth = delegations[_owner][delegationId];
        
        require(auth.isActive, "IDE: Request unauthorized");
        require(msg.sender == auth.delegatee, "IDE: Caller is not the authorized delegatee");
        
        // حماية الغاز والـ MEV: رفض التنفيذ إذا حاول البناء أو البوت التلاعب بسعر الغاز
        require(tx.gasprice <= auth.maxGasPrice, "IDE: Gas price exceeds MEV limit");

        // التحقق من التوقيع الرقمي لمنع انتحال الشخصية أو التلاعب بالـ Payload
        bytes32 messageHash = keccak256(abi.encodePacked(_owner, _chainId, _target, _payload, auth.nonce));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        
        address signer = ethSignedMessageHash.recover(_signature);
        require(signer == _owner, "IDE: Invalid cryptographic signature");

        // زيادة الـ Nonce لمنع هجمات إعادة التشغيل
        delegations[_owner][delegationId].nonce++;
        userNonces[_owner]++;

        // تنفيذ المعاملة الفعلية بالنيابة عن الحساب المفوض
        emit ExecutionTriggered(_owner, msg.sender, _chainId);
        (bool success, bytes memory result) = _target.call{value: msg.value}(_payload);
        require(success, "IDE: Target execution reverted");

        return result;
    }

    /**
     * @dev دالة مساعدة لقراءة بيانات التفويض بسهولة
     */
    function getDelegation(address _owner, uint256 _chainId) external view returns (Delegation memory) {
        bytes32 delegationId = getDelegationId(_owner, _chainId);
        return delegations[_owner][delegationId];
    }
}
