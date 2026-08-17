mkdir -p contracts
cat > contracts/TestTarget.sol <<'EOF'
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
    event ValueSet(uint256 newValue);

    function setValue(uint256 _v) external payable {
        value = _v;
        emit ValueSet(_v);
    }

    function revertIfZero(uint256 _v) external {
        require(_v != 0, "zero not allowed");
    }
}
EOF
