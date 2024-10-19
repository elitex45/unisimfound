// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import "forge-std/Script.sol";
import "../src/UniswapV3Simulator.sol";

contract DeploySimulator is Script {
    function run() external {
        //uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast();

        UniswapV3Simulator simulator = new UniswapV3Simulator();

        vm.stopBroadcast();
    }
}