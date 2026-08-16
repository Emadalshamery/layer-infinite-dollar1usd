// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title InfiniteDelegationEngine (IDE) - Dollar1usd Protocol
 * @dev يسمح بالتفويض الآمن مرِّن عبر السلاسل وإدارة مسارات المعاملات مع دعم حماية MEV.
 * تحسينات أمنية: استخدام OpenZeppelin ECDSA، ReentrancyGuard، تحقق من العناوين، وإدارة Nonce آمنة.
 */
contract InfiniteDelegationEngine is ReentrancyGuard {
    using ECDSA for bytes32;

    // هيكل بيانات التفويض
    struct Delegation {
        address owner;         // صاحب الحساب الأصلي
        address delegatee;     // الجهة المفوضة (البوت أو الوكيل)
        uint256 chainId;       // معرف السلسلة المستهدفة (عبر السلاسل)
        uint256 maxGasPrice;   // الحد الأقصى لسعر الغاز المسموح به لحماية MEV
        uint256 nonce;         // عدد الاستخدامات/Nonce لحماية التوقيعات
        bool isActive;         // حالة التفويض
    }

    // تعيين من معرف التفويض إلى هيكل التفويض
    // معرف التفويض = keccak256(owner, chainId)
    mapping(bytes32 => Delegation) public delegations;

    // تتبع الـ Nonce الخاص بكل owner (بشكل عام)
    mapping(address => uint256) public userNonces;

    // الأحداث (Events) لمزامنة الحالات خارج السلسلة
    event DelegationCreated(address indexed owner, address indexed delegatee, uint256 chainId, bytes32 delegationId);
    event DelegationRevoked(address indexed owner, uint256 chainId, bytes32 delegationId);
    event ExecutionTriggered(address indexed owner, address indexed delegatee, uint256 chainId, bytes32 delegationId);

    // غطاء الحماية للاستدعاء الطارئ
    modifier onlyActiveDelegation(bytes32 delegationId) {
        require(delegations[delegationId].isActive, "IDE: Delegation is not active");
        _;
    }

    /**
     * @dev توليد معرف التفويض الفريد (Delegation ID)
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
        Delegation storage existing = delegations[delegationId];
        require(!existing.isActive, "IDE: Active delegation already exists");

        uint256 nonce = userNonces[msg.sender];

        delegations[delegationId] = Delegation({
            owner: msg.sender,
            delegatee: _delegatee,
            chainId: _chainId,
            maxGasPrice: _maxGasPrice,
            nonce: nonce,
            isActive: true
        });

        emit DelegationCreated(msg.sender, _delegatee, _chainId, delegationId);
    }

    /**
     * @dev نظام التراجع الطارئ (Emergency Revocation) - سحب التفويض فوراً
     */
    function revokeDelegation(uint256 _chainId) external {
        bytes32 delegationId = getDelegationId(msg.sender, _chainId);
        Delegation storage d = delegations[delegationId];
        require(d.isActive, "IDE: Delegation already inactive");
        require(d.owner == msg.sender, "IDE: Not delegation owner");

        d.isActive = false;
        userNonces[msg.sender]++; // زيادة الـ Nonce لتعطيل أي توقيعات قديمة خارج السلسلة فوراً

        emit DelegationRevoked(msg.sender, _chainId, delegationId);
    }

    /**
     * @dev التحقق من شروط الغاز والتوقيع، ثم تنفيذ المعاملة المستهدفة لحماية الحساب من الـ MEV
     * يتوقع توقيع المالك على الرسالة التالية:
     * keccak256(abi.encodePacked(\"IDE_EXECUTE\", owner, chainId, target, payloadHash, nonce))
     */
    function verifyAndExecute(
        address _owner,
        uint256 _chainId,
        address _target,
        bytes calldata _payload,
        bytes calldata _signature
    ) external payable nonReentrant returns (bytes memory) {
        require(_target != address(0), "IDE: target zero address");

        bytes32 delegationId = getDelegationId(_owner, _chainId);
        Delegation storage auth = delegations[delegationId];

        require(auth.isActive, "IDE: Request unauthorized or delegation inactive");
        require(msg.sender == auth.delegatee, "IDE: Caller is not the authorized delegatee");

        // حماية الغاز والـ MEV: رفض التنفيذ إذا تجاوز tx.gasprice الحد
        require(tx.gasprice <= auth.maxGasPrice, "IDE: Gas price exceeds MEV limit");

        // احسب هاش للpayload لتقليل الهجوم على طول الرسالة
        bytes32 payloadHash = keccak256(_payload);

        bytes32 messageHash = keccak256(abi.encodePacked("IDE_EXECUTE", _owner, _chainId, _target, payloadHash, auth.nonce));
        address signer = messageHash.toEthSignedMessageHash().recover(_signature);
        require(signer == _owner, "IDE: Invalid cryptographic signature");

        // زيادة الـ Nonce لمنع هجمات إعادة التشغيل
        auth.nonce++;
        userNonces[_owner]++;

        // تنفيذ المعاملة الفعلية بالنيابة عن الحساب المفوض
        emit ExecutionTriggered(_owner, msg.sender, _chainId, delegationId);
        (bool success, bytes memory result) = _target.call{value: msg.value}(_payload);
        require(success, "IDE: Target execution reverted");

        return result;
    }
}
