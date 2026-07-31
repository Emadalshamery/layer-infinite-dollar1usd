// contracts/core/Dollar1usd.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Dollar1usd is ERC20, ERC20Permit, AccessControl, ReentrancyGuard {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18;
    uint256 public constant FEE_BASIS_POINTS = 5;

    event Minted(address indexed to, uint256 amount, address indexed relayer);
    event Burned(address indexed from, uint256 amount, address indexed relayer);
    event FeeCollected(address indexed collector, uint256 amount);

    constructor(address initialRelayer) 
        ERC20("Dollar1usd", "USD1") 
        ERC20Permit("Dollar1usd") 
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(RELAYER_ROLE, initialRelayer);
        _grantRole(MINTER_ROLE, initialRelayer);
        _grantRole(BURNER_ROLE, initialRelayer);
    }

    function mint(address to, uint256 amount) 
        external 
        onlyRole(MINTER_ROLE) 
        nonReentrant 
    {
        require(to != address(0), "USD1: invalid address");
        require(totalSupply() + amount <= MAX_SUPPLY, "USD1: max supply exceeded");
        _mint(to, amount);
        emit Minted(to, amount, msg.sender);
    }

    function burn(address from, uint256 amount) 
        external 
        onlyRole(BURNER_ROLE) 
        nonReentrant 
    {
        require(from != address(0), "USD1: invalid address");
        _burn(from, amount);
        emit Burned(from, amount, msg.sender);
    }

    function bridgeTransfer(address to, uint256 amount) 
        external 
        onlyRole(RELAYER_ROLE) 
        nonReentrant 
        returns (bool) 
    {
        require(to != address(0), "USD1: invalid recipient");
        _transfer(msg.sender, to, amount);
        return true;
    }

    function _update(address from, address to, uint256 amount) 
        internal 
        override 
    {
        if (hasRole(RELAYER_ROLE, from) && !hasRole(RELAYER_ROLE, to)) {
            uint256 fee = (amount * FEE_BASIS_POINTS) / 10000;
            uint256 amountAfterFee = amount - fee;
            super._update(from, to, amountAfterFee);
            super._update(from, address(this), fee);
            emit FeeCollected(address(this), fee);
        } else {
            super._update(from, to, amount);
        }
    }
}
