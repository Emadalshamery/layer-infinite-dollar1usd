// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../contracts/Dollar1usdToken.sol";
import "../contracts/InfinityEngine.sol";

contract Deploy is Script {
    function run() public returns (address token, address engine) {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        vm.startBroadcast(deployerKey);

        Dollar1usdToken t = new Dollar1usdToken();
        token = address(t);

        InfinityEngine eng = new InfinityEngine();
        engine = address(eng);

        vm.stopBroadcast();
    }
}
