// contracts/core/SovereignRelayer.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SovereignRelayer is AccessControl, ReentrancyGuard {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 public constant MAX_GAS_PRICE = 200 gwei;
    uint256 public constant MIN_EXECUTION_DELAY = 1 minutes;

    struct Intent {
        address target;
        bytes data;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
        address signer;
        uint256 maxGasPrice;
    }

    mapping(bytes32 => bool) public executedIntents;
    mapping(address => uint256) public nonces;
    mapping(address => bool) public trustedRelayers;

    event IntentExecuted(
        bytes32 indexed intentHash,
        address indexed executor,
        address indexed signer,
        uint256 nonce
    );
    event RelayerTrusted(address indexed relayer, bool trusted);
    event IntentFailed(bytes32 indexed intentHash, string reason);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(EXECUTOR_ROLE, msg.sender);
    }

    function executeIntent(Intent calldata intent, bytes calldata signature) 
        external 
        nonReentrant 
        returns (bool)
    {
        require(intent.deadline >= block.timestamp, "Relayer: intent expired");
        require(intent.nonce == nonces[intent.signer], "Relayer: invalid nonce");
        require(tx.gasprice <= intent.maxGasPrice, "Relayer: gas price too high");
        require(tx.gasprice <= MAX_GAS_PRICE, "Relayer: gas price exceeds max");

        bytes32 intentHash = _hashIntent(intent);
        require(!executedIntents[intentHash], "Relayer: intent already executed");

        bytes32 messageHash = intentHash.toEthSignedMessageHash();
        address recoveredSigner = messageHash.recover(signature);
        require(recoveredSigner == intent.signer, "Relayer: invalid signature");

        nonces[intent.signer]++;

        bytes memory result;
        bool success;
        (success, result) = intent.target.call{value: intent.value}(intent.data);

        if (!success) {
            nonces[intent.signer]--;
            string memory error = _decodeError(result);
            emit IntentFailed(intentHash, error);
            revert(string(abi.encodePacked("Relayer: execution failed: ", error)));
        }

        executedIntents[intentHash] = true;
        emit IntentExecuted(intentHash, msg.sender, intent.signer, intent.nonce);

        return true;
    }

    function _hashIntent(Intent calldata intent) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                intent.target,
                intent.data,
                intent.value,
                intent.nonce,
                intent.deadline,
                intent.signer,
                intent.maxGasPrice
            )
        );
    }

    function _decodeError(bytes memory result) internal pure returns (string memory) {
        if (result.length < 68) return "Execution failed";
        uint256 errorLength = abi.decode(result[4:], (uint256));
        return string(result[68:68 + errorLength]);
    }

    function trustRelayer(address relayer) external onlyRole(ADMIN_ROLE) {
        trustedRelayers[relayer] = true;
        emit RelayerTrusted(relayer, true);
    }

    function revokeRelayer(address relayer) external onlyRole(ADMIN_ROLE) {
        trustedRelayers[relayer] = false;
        emit RelayerTrusted(relayer, false);
    }

    function withdrawGas() external onlyRole(ADMIN_ROLE) {
        payable(msg.sender).transfer(address(this).balance);
    }

    receive() external payable {}
}
