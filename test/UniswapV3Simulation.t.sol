// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../src/UniswapV3Simulator.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract UniswapV3SimulationTest is Test {
    using SafeERC20 for IERC20;

    UniswapV3Simulator public simulator;
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20 public constant USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    address public constant POOL = 0x3416cF6C708Da44DB2624D63ea0AAef7113527C6;

    uint256 public tokenId;

    function setUp() public {
        vm.createSelectFork("anvil");
        simulator = new UniswapV3Simulator();
    }

    function testSimulation() public {
        // Directly set token balances
        deal(address(USDC), address(this), 1_000_000 * 1e6);
        deal(address(USDT), address(this), 1_000_000 * 1e6);

        // Check balances
        console.log("Test contract USDC balance:", USDC.balanceOf(address(this)));
        console.log("Test contract USDT balance:", USDT.balanceOf(address(this)));

        // Approve USDC and USDT using SafeERC20
        console.log("Approving USDC and USDT...");
        USDC.safeApprove(address(simulator), type(uint256).max);
        USDT.safeApprove(address(simulator), type(uint256).max);
        console.log("Approved USDC and USDT");

        // Check allowances
        console.log("USDC allowance:", USDC.allowance(address(this), address(simulator)));
        console.log("USDT allowance:", USDT.allowance(address(this), address(simulator)));

        // Provide initial liquidity
        console.log("Providing liquidity...");
        try simulator.provideLiquidity(
            address(USDC),
            address(USDT),
            100, // 0.01% fee tier
            -11,
            9,
            1_000_000 * 1e6,
            1_000_000 * 1e6
        ) returns (uint256 _tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) {
            tokenId = _tokenId;
            console.log("Provided liquidity successfully. TokenId:", tokenId);
            //console.log("Liquidity:", liquidity);
            console.log("Amount0:", amount0);
            console.log("Amount1:", amount1);
        } catch Error(string memory reason) {
            console.log("Providing liquidity failed. Reason:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("Providing liquidity failed. Low-level data:", vm.toString(lowLevelData));
        }

        // Simulate transactions from JSON data
        
        //eigen.strategyManager = abi.decode(vm.parseJson(json, ".eigen.strategyManager"), (address));
        //eigen.delegationManager = abi.decode(vm.parseJson(json, ".eigen.delegationManager"), (address));

        console.log("before reading the file");
        // string memory projectFile = string(abi.encodePacked(vm.projectRoot(), "/data/abc.json"));
        // console.log(projectFile);
        string memory json = vm.readFile("/Users/engineer/Documents/workspace/zeru/analysis/unisimfound/data/sample.json");
        console.log("after reading the file");
        bytes memory parsedData = vm.parseJson(json);
        console.log("after parsing the file");

        
        uint256[] memory blockNumbers = abi.decode(parsedData, (uint256[]));
        string[] memory eventTypes = abi.decode(parsedData, (string[]));
        
        for (uint256 i = 0; i < blockNumbers.length; i++) {
            console.log(i,blockNumbers[i]);
            vm.roll(blockNumbers[i]);
            
            if (keccak256(abi.encodePacked(eventTypes[i])) == keccak256(abi.encodePacked("swaps"))) {
                console.log("doing swap");
                simulateSwap(parsedData, i);
            } else if (keccak256(abi.encodePacked(eventTypes[i])) == keccak256(abi.encodePacked("mints"))) {
                console.log("doing mint");
                simulateMint(parsedData, i);
            }
            // Note: We're not simulating burns or collects as per the instructions
        }

        // Collect fees at the end of the simulation
        (uint256 amount0, uint256 amount1) = simulator.collectFees(tokenId);
        console.log("Collected fees: USDC:", amount0, "USDT:", amount1);
    }

    function simulateSwap(bytes memory parsedData, uint256 index) internal {
        (address tokenIn, uint256 amountIn) = abi.decode(parsedData, (address, uint256));
        address tokenOut = tokenIn == address(USDC) ? address(USDT) : address(USDC);
        
        simulator.swapTokens(tokenIn, tokenOut, 100, amountIn, 0);
    }

    function simulateMint(bytes memory parsedData, uint256 index) internal {
        (int24 tickLower, int24 tickUpper, uint256 amount0, uint256 amount1) = abi.decode(parsedData, (int24, int24, uint256, uint256));
        
        simulator.provideLiquidity(address(USDC), address(USDT), 100, tickLower, tickUpper, amount0, amount1);
    }
}