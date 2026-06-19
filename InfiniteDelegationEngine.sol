// SPDX-License-Identifier: MIT
pragma warning disable;
pragma solidity ^0.8.24;

/**
 * @title InfiniteDelegationEngine (IDE) - Dollar1usd Protocol
 * @dev يسمح بالتفويض الآمن مرن الحالات عبر السلاسل وإدارة مسارات المعاملات.
 */
contract InfiniteDelegationEngine {

    // هيكل بيانات التفويض
    struct Delegation {
        address delegatee;    // الجهة المفوضة (البوت أو الوكيل)
        bytes32 chainId;      // معرف السلسلة المستهدفة (عبر السلاسل)
        uint256 maxGasPrice;  // الحد الأقصى لسعر الغاز المسموح به لحماية MEV
        bool isActive;        // حالة التفويض
    }

    // تعيين من عنوان المستخدم إلى معرف التفويض الخاص به
    mapping(address => mapping(bytes32 => Delegation)) public delegations;

    // الأحداث (Events) لمزامنة الحالات خارج السلسلة (Off-chain Indexing)
    event DelegationCreated(address indexed dclOwner, address indexed delegatee, bytes32 chainId);
    event DelegationRevoked(address indexed dclOwner, bytes32 chainId);
    event ExecutionTriggered(address indexed dclOwner, address indexed delegatee, bytes32 chainId);

    // غطاء الحماية للاستدعاء الطارئ (Emergency Rollback)
    modifier onlyDclOwner(bytes32 delegationId) {
        require(delegations[msg.sender][delegationId].isActive, "IDE: Delegation is not active or not owned");
        _;
    }

    /**
     * @dev إنشاء تفويض جديد آمن وغير حاضن
     */
    function createDelegation(
        address _delegatee,
        bytes32 _chainId,
        uint256 _maxGasPrice
    ) external {
        require(_delegatee != address(0), "IDE: Invalid delegatee address");
        
        bytes32 delegationId = keccak256(abi.encodePacked(msg.sender, _chainId));
        
        delegations[msg.sender][delegationId] = Delegation({
            delegatee: _delegatee,
            chainId: _chainId,
            maxGasPrice: _maxGasPrice,
            isActive: true
        });

        emit DelegationCreated(msg.sender, _delegatee, _chainId);
    }

    /**
     * @dev نظام التراجع الطارئ (Emergency Revocation) - سحب التفويض فوراً
     */
    function revokeDelegation(bytes32 _chainId) external {
        bytes32 delegationId = keccak256(abi.encodePacked(msg.sender, _chainId));
        require(delegations[msg.sender][delegationId].isActive, "IDE: Delegation already inactive");
        
        delegations[msg.sender][delegationId].isActive = false;
        
        emit DelegationRevoked(msg.sender, _chainId);
    }

    /**
     * @dev التحقق من شروط الغاز لحماية المعاملة من بناء الـ MEV الخبيث قبل التمرير
     */
    function verifyAndExecute(address _owner, bytes32 _chainId, bytes calldata _payload) external view returns (bool) {
        bytes32 delegationId = keccak256(abi.encodePacked(_owner, _chainId));
        Delegation memory auth = delegations[_owner][delegationId];
        
        require(auth.isActive, "IDE: Request unauthorized");
        require(msg.sender == auth.delegatee, "IDE: Caller is not the authorized delegatee");
        
        // حماية الغاز و الـ MEV: رفض التنفيذ إذا كان الغاز الحالي أعلى من المحدد تجنباً للهجمات
        if (tx.gasprice > auth.maxGasPrice) {
            return false; 
        }

        // هنا يتم ربط التمرير عبر السلاسل لاحقاً بناءً على الـ Payload
        return true;
    }
}
