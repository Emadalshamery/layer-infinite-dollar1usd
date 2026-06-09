// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/**
 * @title UnifiedIdentitySystem
 * @dev نظام الهويات الموحدة - هوية واحدة عبر جميع السلاسل
 * @notice يدير الهويات الموحدة، ربط العناوين، والبيانات التعريفية الآمنة
 * @author Emad Alshamery
 */
contract UnifiedIdentitySystem is Ownable, ReentrancyGuard, EIP712 {
    using ECDSA for bytes32;

    // ============ CONSTANTS ============
    string public constant VERSION = "1.0.0";
    
    bytes32 private constant IDENTITY_TYPEHASH =
        keccak256(
            "Identity(address user,string username,bytes32 profileHash,uint256 nonce)"
        );

    // ============ STATE VARIABLES ============
    
    /// @dev كلمة السر الرئيسية
    bytes32 private immutable identitySecret;
    
    struct UnifiedIdentity {
        address primaryAddress;
        address[] linkedAddresses;
        string username;
        bytes32 profileHash;
        uint256 createdAt;
        uint256 lastUpdatedAt;
        bool privacyMode;
        bool verified;
    }
    
    struct ProfileData {
        string displayName;
        string avatarHash;
        string bio;
        mapping(string => string) customFields;
    }
    
    struct AssetSnapshot {
        uint256 balance;
        uint256 timestamp;
        string chainName;
    }
    
    /// @dev خريطة الهويات
    mapping(bytes32 => UnifiedIdentity) public identities;
    mapping(bytes32 => ProfileData) private profileData;
    mapping(address => bytes32) public addressToIdentity;
    mapping(bytes32 => mapping(string => AssetSnapshot)) public assetSnapshots;
    
    /// @dev معرف الهوية العريق
    uint256 private identityCounter;
    
    /// @dev الموافقون على التحقق
    address[] private verifiers;
    mapping(address => bool) private isVerifier;
    
    // ============ EVENTS ============
    event IdentityCreated(
        indexed bytes32 identityId,
        indexed address primaryAddress,
        string username
    );
    
    event AddressLinked(
        indexed bytes32 identityId,
        indexed address newAddress
    );
    
    event AddressUnlinked(
        indexed bytes32 identityId,
        indexed address removedAddress
    );
    
    event ProfileUpdated(
        indexed bytes32 identityId,
        string displayName
    );
    
    event IdentityVerified(
        indexed bytes32 identityId,
        indexed address verifier
    );
    
    event PrivacyModeToggled(
        indexed bytes32 identityId,
        bool privacyMode
    );
    
    event AssetSnapshotRecorded(
        indexed bytes32 identityId,
        string chainName,
        uint256 balance
    );

    // ============ MODIFIERS ============
    
    modifier validSecret(bytes32 _secret) {
        require(
            keccak256(abi.encodePacked(_secret)) == keccak256(abi.encodePacked(identitySecret)),
            "UnifiedIdentity: Invalid secret"
        );
        _;
    }
    
    modifier identityExists(bytes32 _identityId) {
        require(
            identities[_identityId].primaryAddress != address(0),
            "UnifiedIdentity: Identity does not exist"
        );
        _;
    }
    
    modifier onlyIdentityOwner(bytes32 _identityId) {
        bytes32 userIdentityId = addressToIdentity[msg.sender];
        require(
            userIdentityId == _identityId,
            "UnifiedIdentity: Not identity owner"
        );
        _;
    }
    
    modifier onlyVerifier() {
        require(isVerifier[msg.sender], "UnifiedIdentity: Not a verifier");
        _;
    }

    // ============ CONSTRUCTOR ============
    
    constructor(
        bytes32 _identitySecret,
        address[] memory _initialVerifiers
    ) EIP712("Layer∞-Identity", "1.0.0") {
        require(_identitySecret != bytes32(0), "Invalid identity secret");
        require(_initialVerifiers.length > 0, "At least one verifier required");
        
        identitySecret = _identitySecret;
        
        for (uint256 i = 0; i < _initialVerifiers.length; i++) {
            require(_initialVerifiers[i] != address(0), "Invalid verifier");
            verifiers.push(_initialVerifiers[i]);
            isVerifier[_initialVerifiers[i]] = true;
        }
    }

    // ============ IDENTITY CREATION & MANAGEMENT ============
    
    /**
     * @dev إنشاء هوية موحدة جديدة
     */
    function createIdentity(
        string memory _username,
        bytes32 _profileHash,
        bool _privacyMode,
        bytes32 _secret
    ) 
        external 
        nonReentrant 
        validSecret(_secret)
        returns (bytes32 identityId)
    {
        require(bytes(_username).length > 0, "UnifiedIdentity: Username required");
        require(bytes(_username).length <= 50, "UnifiedIdentity: Username too long");
        require(addressToIdentity[msg.sender] == bytes32(0), "UnifiedIdentity: Identity already exists");
        
        identityId = keccak256(abi.encode(msg.sender, identityCounter++, block.timestamp));
        
        UnifiedIdentity storage identity = identities[identityId];
        identity.primaryAddress = msg.sender;
        identity.linkedAddresses.push(msg.sender);
        identity.username = _username;
        identity.profileHash = _profileHash;
        identity.createdAt = block.timestamp;
        identity.lastUpdatedAt = block.timestamp;
        identity.privacyMode = _privacyMode;
        identity.verified = false;
        
        addressToIdentity[msg.sender] = identityId;
        
        emit IdentityCreated(identityId, msg.sender, _username);
        
        return identityId;
    }
    
    /**
     * @dev ربط عنوان إضافي مع التحقق من الملكية
     */
    function linkAddress(
        bytes32 _identityId,
        address _newAddress,
        bytes calldata _signature,
        bytes32 _secret
    ) 
        external 
        nonReentrant 
        identityExists(_identityId)
        onlyIdentityOwner(_identityId)
        validSecret(_secret)
    {
        require(_newAddress != address(0), "UnifiedIdentity: Invalid address");
        require(addressToIdentity[_newAddress] == bytes32(0), "UnifiedIdentity: Address already linked");
        
        // التحقق من التوقيع
        bytes32 messageHash = keccak256(abi.encode(_identityId, _newAddress, block.timestamp));
        address signer = messageHash.recover(_signature);
        require(signer == _newAddress, "UnifiedIdentity: Invalid signature");
        
        UnifiedIdentity storage identity = identities[_identityId];
        identity.linkedAddresses.push(_newAddress);
        identity.lastUpdatedAt = block.timestamp;
        
        addressToIdentity[_newAddress] = _identityId;
        
        emit AddressLinked(_identityId, _newAddress);
    }
    
    /**
     * @dev فصل عنوان
     */
    function unlinkAddress(
        bytes32 _identityId,
        address _addressToRemove,
        bytes32 _secret
    ) 
        external 
        nonReentrant 
        identityExists(_identityId)
        onlyIdentityOwner(_identityId)
        validSecret(_secret)
    {
        require(_addressToRemove != address(0), "UnifiedIdentity: Invalid address");
        require(
            identities[_identityId].primaryAddress != _addressToRemove,
            "UnifiedIdentity: Cannot unlink primary address"
        );
        
        UnifiedIdentity storage identity = identities[_identityId];
        
        // البحث عن العنوان وحذفه
        for (uint256 i = 0; i < identity.linkedAddresses.length; i++) {
            if (identity.linkedAddresses[i] == _addressToRemove) {
                identity.linkedAddresses[i] = identity.linkedAddresses[
                    identity.linkedAddresses.length - 1
                ];
                identity.linkedAddresses.pop();
                identity.lastUpdatedAt = block.timestamp;
                
                delete addressToIdentity[_addressToRemove];
                
                emit AddressUnlinked(_identityId, _addressToRemove);
                return;
            }
        }
        
        revert("UnifiedIdentity: Address not found");
    }

    // ============ PROFILE MANAGEMENT ============
    
    /**
     * @dev تحديث بيانات الملف الشخصي
     */
    function updateProfile(
        bytes32 _identityId,
        string memory _displayName,
        string memory _avatarHash,
        string memory _bio,
        bytes32 _secret
    ) 
        external 
        nonReentrant 
        identityExists(_identityId)
        onlyIdentityOwner(_identityId)
        validSecret(_secret)
    {
        require(bytes(_displayName).length <= 100, "UnifiedIdentity: Display name too long");
        require(bytes(_bio).length <= 500, "UnifiedIdentity: Bio too long");
        
        identities[_identityId].lastUpdatedAt = block.timestamp;
        
        ProfileData storage profile = profileData[_identityId];
        profile.displayName = _displayName;
        profile.avatarHash = _avatarHash;
        profile.bio = _bio;
        
        emit ProfileUpdated(_identityId, _displayName);
    }
    
    /**
     * @dev الحصول على بيانات الملف الشخصي
     */
    function getProfile(bytes32 _identityId)
        external
        view
        identityExists(_identityId)
        returns (
            string memory displayName,
            string memory avatarHash,
            string memory bio
        )
    {
        ProfileData storage profile = profileData[_identityId];
        return (profile.displayName, profile.avatarHash, profile.bio);
    }

    // ============ VERIFICATION ============
    
    /**
     * @dev التحقق من الهوية (من قبل الموثق المأذون)
     */
    function verifyIdentity(
        bytes32 _identityId,
        bytes32 _secret
    ) 
        external 
        identityExists(_identityId)
        onlyVerifier
        validSecret(_secret)
    {
        require(!identities[_identityId].verified, "UnifiedIdentity: Already verified");
        
        identities[_identityId].verified = true;
        identities[_identityId].lastUpdatedAt = block.timestamp;
        
        emit IdentityVerified(_identityId, msg.sender);
    }

    // ============ PRIVACY MODE ============
    
    /**
     * @dev تبديل وضع الخصوصية
     */
    function togglePrivacyMode(
        bytes32 _identityId,
        bytes32 _secret
    ) 
        external 
        identityExists(_identityId)
        onlyIdentityOwner(_identityId)
        validSecret(_secret)
    {
        bool newPrivacyMode = !identities[_identityId].privacyMode;
        identities[_identityId].privacyMode = newPrivacyMode;
        identities[_identityId].lastUpdatedAt = block.timestamp;
        
        emit PrivacyModeToggled(_identityId, newPrivacyMode);
    }

    // ============ ASSET TRACKING ============
    
    /**
     * @dev تسجيل لقطة من الأصول
     */
    function recordAssetSnapshot(
        bytes32 _identityId,
        string memory _chainName,
        uint256 _balance,
        bytes32 _secret
    ) 
        external 
        identityExists(_identityId)
        onlyIdentityOwner(_identityId)
        validSecret(_secret)
    {
        require(bytes(_chainName).length > 0, "UnifiedIdentity: Chain name required");
        
        assetSnapshots[_identityId][_chainName] = AssetSnapshot({
            balance: _balance,
            timestamp: block.timestamp,
            chainName: _chainName
        });
        
        emit AssetSnapshotRecorded(_identityId, _chainName, _balance);
    }
    
    /**
     * @dev الحصول على لقطة الأصول
     */
    function getAssetSnapshot(bytes32 _identityId, string memory _chainName)
        external
        view
        identityExists(_identityId)
        returns (uint256 balance, uint256 timestamp)
    {
        AssetSnapshot storage snapshot = assetSnapshots[_identityId][_chainName];
        return (snapshot.balance, snapshot.timestamp);
    }

    // ============ VIEW FUNCTIONS ============
    
    /**
     * @dev الحصول على معلومات الهوية
     */
    function getIdentity(bytes32 _identityId)
        external
        view
        identityExists(_identityId)
        returns (
            address primaryAddress,
            uint256 linkedAddressCount,
            string memory username,
            bool verified,
            uint256 createdAt
        )
    {
        UnifiedIdentity storage identity = identities[_identityId];
        return (
            identity.primaryAddress,
            identity.linkedAddresses.length,
            identity.username,
            identity.verified,
            identity.createdAt
        );
    }
    
    /**
     * @dev الحصول على جميع العناوين المرتبطة
     */
    function getLinkedAddresses(bytes32 _identityId)
        external
        view
        identityExists(_identityId)
        returns (address[] memory)
    {
        return identities[_identityId].linkedAddresses;
    }
    
    /**
     * @dev البحث عن الهوية من خلال العنوان
     */
    function getIdentityByAddress(address _address)
        external
        view
        returns (bytes32)
    {
        return addressToIdentity[_address];
    }
}
