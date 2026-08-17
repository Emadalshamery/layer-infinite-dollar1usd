mkdir -p contracts
cat > contracts/TestTarget.sol <<'EOF'
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract TestTarget {
    uint256 public value;
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
