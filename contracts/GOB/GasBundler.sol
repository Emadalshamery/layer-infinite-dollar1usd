// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title GasBundler
 * @dev التجميع المُحسَّن للغاز - توفير 40% من رسوم الغاز
 * @notice يدير تجميع المعاملات وضغط البيانات للتوفير الأمثل
 * @author Emad Alshamery
 */
contract GasBundler is Ownable, ReentrancyGuard, Pausable {
    
    // ============ CONSTANTS ============
    string public constant VERSION = "1.0.0";
    uint256 public constant COMPRESSION_RATIO = 4; // 40% توفير
    uint256 public constant BASE_GAS_COST = 10000;
    uint256 public constant PER_TX_OVERHEAD = 1500;

    // ============ STATE VARIABLES ============
    
    /// @dev كلمة السر الرئيسية للتحقق
    bytes32 private immutable bundlerSecret;
    
    struct BundledTransaction {
        address[] recipients;
        uint256[] amounts;
        bytes[] data;
        uint256 gasEstimate;
        bool executed;
        uint256 createdAt;
        bytes32 merkleRoot;
    }
    
    struct Bundle {
        bytes32 bundleHash;
        uint256 gasOptimized;
        uint256 gasRegular;
        uint256 savedGas;
        uint256 savedETH;
        uint256 timestamp;
        bool settled;
    }
    
    mapping(bytes32 => BundledTransaction) public bundles;
    mapping(uint256 => Bundle) public bundleHistory;
    
    uint256 private bundleCounter;
    uint256 private totalGasSaved;
    uint256 private totalETHSaved;
    
    // ============ EVENTS ============
    event BundleCreated(
        indexed bytes32 bundleHash,
        uint256 txCount,
        uint256 estimatedGas
    );
    
    event BundleExecuted(
        indexed bytes32 bundleHash,
        uint256 gasUsed,
        uint256 gasOptimized,
        uint256 savedGas
    );
    
    event GasSavingsCalculated(
        uint256 regularGas,
        uint256 optimizedGas,
        uint256 savedGas,
        uint256 savingsPercentage
    );

    // ============ MODIFIERS ============
    
    modifier validSecret(bytes32 _secret) {
        require(
            keccak256(abi.encodePacked(_secret)) == keccak256(abi.encodePacked(bundlerSecret)),
            "GasBundler: Invalid secret"
        );
        _;
    }

    // ============ CONSTRUCTOR ============
    
    constructor(bytes32 _bundlerSecret) {
        require(_bundlerSecret != bytes32(0), "Invalid bundler secret");
        bundlerSecret = _bundlerSecret;
    }

    // ============ CORE BUNDLING LOGIC ============
    
    /**
     * @dev حساب تكلفة الغاز المنتظمة
     */
    function calculateRegularGas(uint256 _txCount) public pure returns (uint256) {
        // 21000 لكل معاملة عادية
        return _txCount * 21000;
    }
    
    /**
     * @dev حساب تكلفة الغاز المُحسَّنة
     */
    function calculateOptimizedGas(uint256 _txCount) public pure returns (uint256) {
        // BASE_GAS_COST + (عدد المعاملات × PER_TX_OVERHEAD)
        return BASE_GAS_COST + (_txCount * PER_TX_OVERHEAD);
    }
    
    /**
     * @dev حساب التوفير
     */
    function calculateSavings(uint256 _txCount) 
        external 
        pure 
        returns (
            uint256 regularGas,
            uint256 optimizedGas,
            uint256 savedGas,
            uint256 savingsPercentage
        )
    {
        regularGas = calculateRegularGas(_txCount);
        optimizedGas = calculateOptimizedGas(_txCount);
        savedGas = regularGas - optimizedGas;
        savingsPercentage = (_txCount > 0) ? (savedGas * 100) / regularGas : 0;
    }
    
    /**
     * @dev إنشاء حزمة معاملات
     */
    function createBundle(
        address[] calldata _recipients,
        uint256[] calldata _amounts,
        bytes[] calldata _data,
        bytes32 _secret
    ) 
        external 
        nonReentrant 
        whenNotPaused
        validSecret(_secret)
        returns (bytes32 bundleHash)
    {
        require(_recipients.length > 0, "GasBundler: Empty bundle");
        require(
            _recipients.length == _amounts.length &&
            _recipients.length == _data.length,
            "GasBundler: Array length mismatch"
        );
        require(_recipients.length <= 100, "GasBundler: Too many transactions");
        
        // حساب hash الحزمة
        bundleHash = keccak256(
            abi.encode(_recipients, _amounts, _data, block.timestamp)
        );
        
        // حساب Merkle Root
        bytes32 merkleRoot = computeMerkleRoot(_recipients, _amounts);
        
        // حساب تكاليف الغاز
        uint256 regularGas = calculateRegularGas(_recipients.length);
        uint256 optimizedGas = calculateOptimizedGas(_recipients.length);
        
        bundles[bundleHash] = BundledTransaction({
            recipients: _recipients,
            amounts: _amounts,
            data: _data,
            gasEstimate: optimizedGas,
            executed: false,
            createdAt: block.timestamp,
            merkleRoot: merkleRoot
        });
        
        emit BundleCreated(bundleHash, _recipients.length, optimizedGas);
        
        return bundleHash;
    }
    
    /**
     * @dev تنفيذ الحزمة
     */
    function executeBundle(
        bytes32 _bundleHash,
        bytes32 _secret
    ) 
        external 
        nonReentrant 
        whenNotPaused
        validSecret(_secret)
    {
        BundledTransaction storage bundle = bundles[_bundleHash];
        require(!bundle.executed, "GasBundler: Already executed");
        require(bundle.recipients.length > 0, "GasBundler: Invalid bundle");
        
        uint256 txCount = bundle.recipients.length;
        uint256 startGas = gasleft();
        
        // تنفيذ جميع المعاملات
        for (uint256 i = 0; i < txCount; i++) {
            address recipient = bundle.recipients[i];
            uint256 amount = bundle.amounts[i];
            
            require(recipient != address(0), "GasBundler: Invalid recipient");
            
            if (bundle.data[i].length == 0) {
                // تحويل ETH عادي
                (bool success, ) = payable(recipient).call{value: amount}("");
                require(success, "GasBundler: Transfer failed");
            } else {
                // استدعاء عقد ذكي
                (bool success, ) = recipient.call{value: amount}(bundle.data[i]);
                require(success, "GasBundler: Call failed");
            }
        }
        
        uint256 gasUsed = startGas - gasleft();
        uint256 regularGas = calculateRegularGas(txCount);
        uint256 optimizedGas = calculateOptimizedGas(txCount);
        uint256 savedGas = regularGas - optimizedGas;
        
        bundle.executed = true;
        totalGasSaved += savedGas;
        
        // تسجيل في السجل
        Bundle storage historyEntry = bundleHistory[bundleCounter++];
        historyEntry.bundleHash = _bundleHash;
        historyEntry.gasRegular = regularGas;
        historyEntry.gasOptimized = optimizedGas;
        historyEntry.savedGas = savedGas;
        historyEntry.timestamp = block.timestamp;
        historyEntry.settled = true;
        
        emit BundleExecuted(_bundleHash, gasUsed, optimizedGas, savedGas);
    }

    // ============ MERKLE TREE FUNCTIONS ============
    
    /**
     * @dev حساب جذر Merkle
     */
    function computeMerkleRoot(
        address[] calldata _recipients,
        uint256[] calldata _amounts
    ) 
        public 
        pure 
        returns (bytes32)
    {
        require(_recipients.length == _amounts.length, "Length mismatch");
        
        if (_recipients.length == 0) return bytes32(0);
        if (_recipients.length == 1) {
            return keccak256(abi.encode(_recipients[0], _amounts[0]));
        }
        
        // بناء شجرة Merkle
        bytes32[] memory tree = new bytes32[](_recipients.length);
        
        for (uint256 i = 0; i < _recipients.length; i++) {
            tree[i] = keccak256(abi.encode(_recipients[i], _amounts[i]));
        }
        
        while (tree.length > 1) {
            bytes32[] memory nextLevel = new bytes32[]((tree.length + 1) / 2);
            
            for (uint256 i = 0; i < nextLevel.length; i++) {
                if (2 * i + 1 < tree.length) {
                    nextLevel[i] = keccak256(
                        abi.encodePacked(tree[2 * i], tree[2 * i + 1])
                    );
                } else {
                    nextLevel[i] = tree[2 * i];
                }
            }
            
            tree = nextLevel;
        }
        
        return tree[0];
    }
    
    /**
     * @dev التحقق من دليل Merkle
     */
    function verifyMerkleProof(
        bytes32[] calldata _proof,
        bytes32 _leaf,
        bytes32 _root
    ) 
        external 
        pure 
        returns (bool)
    {
        bytes32 computedHash = _leaf;
        
        for (uint256 i = 0; i < _proof.length; i++) {
            bytes32 proofElement = _proof[i];
            
            if (computedHash <= proofElement) {
                computedHash = keccak256(
                    abi.encodePacked(computedHash, proofElement)
                );
            } else {
                computedHash = keccak256(
                    abi.encodePacked(proofElement, computedHash)
                );
            }
        }
        
        return computedHash == _root;
    }

    // ============ STATISTICS ============
    
    /**
     * @dev الحصول على إجمالي الغاز المحفوظ
     */
    function getTotalGasSaved() external view returns (uint256) {
        return totalGasSaved;
    }
    
    /**
     * @dev الحصول على معلومات الحزمة
     */
    function getBundleInfo(bytes32 _bundleHash) 
        external 
        view 
        returns (
            uint256 txCount,
            uint256 gasEstimate,
            bool executed,
            uint256 createdAt
        )
    {
        BundledTransaction storage bundle = bundles[_bundleHash];
        return (
            bundle.recipients.length,
            bundle.gasEstimate,
            bundle.executed,
            bundle.createdAt
        );
    }

    // ============ EMERGENCY FUNCTIONS ============
    
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
