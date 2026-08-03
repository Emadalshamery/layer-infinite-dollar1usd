// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract TestTarget {
    uint256 public value;

    event Called(uint256 value, address caller, uint256 valueSent);

    function doSomething(uint256 _value) external payable returns (uint256) {
        value = _value;
        emit Called(_value, msg.sender, msg.value);
        return value;
    }

    function willRevert() external pure {
        revert("TestTarget: revert on purpose");
    }
}
