// contracts/core/InfiniteDelegationEngine.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract InfiniteDelegationEngine is AccessControl {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    bytes32 public constant DELEGATOR_ROLE = keccak256("DELEGATOR_ROLE");

    struct Delegation {
        address delegate;
        uint256 expiresAt;
        uint256 nonce;
        bytes32[] allowedSelectors;
        uint256 maxGasPrice;
    }

    mapping(address => mapping(address => Delegation)) public delegations;
    mapping(address => uint256) public nonces;
    mapping(address => bool) public isActiveDelegate;

    event DelegationCreated(
        address indexed delegator,
        address indexed delegate,
        uint256 expiresAt,
        uint256 nonce
    );
    event DelegationRevoked(address indexed delegator, address indexed delegate);
    event DelegateActivated(address indexed delegate, bool active);

    function createDelegation(
        address delegate,
        uint256 duration,
        bytes32[] calldata allowedSelectors,
        uint256 maxGasPrice,
        bytes calldata signature
    ) external {
        require(delegate != address(0), "IDE: invalid delegate");
        require(duration > 0, "IDE: invalid duration");
        require(allowedSelectors.length > 0, "IDE: no selectors");

        uint256 expiresAt = block.timestamp + duration;
        uint256 nonce = nonces[msg.sender]++;

        bytes32 delegationHash = _hashDelegation(
            msg.sender,
            delegate,
            expiresAt,
            nonce,
            allowedSelectors,
            maxGasPrice
        );

        bytes32 messageHash = delegationHash.toEthSignedMessageHash();
        address recoveredSigner = messageHash.recover(signature);
        require(recoveredSigner == msg.sender, "IDE: invalid signature");

        delegations[msg.sender][delegate] = Delegation({
            delegate: delegate,
            expiresAt: expiresAt,
            nonce: nonce,
            allowedSelectors: allowedSelectors,
            maxGasPrice: maxGasPrice
        });

        emit DelegationCreated(msg.sender, delegate, expiresAt, nonce);
    }

    function executeDelegated(
        address delegator,
        address target,
        bytes calldata data,
        uint256 value
    ) external returns (bool) {
        Delegation memory delegation = delegations[delegator][msg.sender];
        require(msg.sender == delegation.delegate, "IDE: not delegated");
        require(block.timestamp <= delegation.expiresAt, "IDE: delegation expired");
        require(tx.gasprice <= delegation.maxGasPrice, "IDE: gas price too high");
        require(isActiveDelegate[msg.sender], "IDE: delegate not active");

        bytes4 selector = bytes4(data[0:4]);
        bool allowed = false;
        for (uint256 i = 0; i < delegation.allowedSelectors.length; i++) {
            if (delegation.allowedSelectors[i] == selector) {
                allowed = true;
                break;
            }
        }
        require(allowed, "IDE: selector not allowed");

        (bool success, ) = target.call{value: value}(data);
        require(success, "IDE: execution failed");

        return true;
    }

    function _hashDelegation(
        address delegator,
        address delegate,
        uint256 expiresAt,
        uint256 nonce,
        bytes32[] calldata allowedSelectors,
        uint256 maxGasPrice
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                delegator,
                delegate,
                expiresAt,
                nonce,
                allowedSelectors,
                maxGasPrice
            )
        );
    }

    function activateDelegate(address delegate) external onlyRole(DELEGATOR_ROLE) {
        isActiveDelegate[delegate] = true;
        emit DelegateActivated(delegate, true);
    }
}
