// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import "forge-std/Test.sol";
import "../src/UniswapV3Simulator.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20Mintable is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract UniswapV3SimulationTest is Test {
    UniswapV3Simulator public simulator;
    IERC20Mintable public constant USDC = IERC20Mintable(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IERC20Mintable public constant USDT = IERC20Mintable(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    address public constant POOL = 0x3416cF6C708Da44DB2624D63ea0AAef7113527C6;
    address public constant USDC_OWNER = 0xFcb19e6a322b27c06842A71e8c725399f049AE3a;
    address public constant USDT_OWNER = 0xC6CDE7C39eB2f0F0095F41570af89eFC2C1Ea828;

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

        // Provide initial liquidity
        USDC.approve(address(simulator), type(uint256).max);
        console.log("Approved USDC");
        USDT.approve(address(simulator), type(uint256).max);
        console.log("Approved USDT");
        (tokenId, , , ) = simulator.provideLiquidity(
            address(USDC),
            address(USDT),
            100, // 0.01% fee tier
            -11,
            9,
            1_000_000 * 1e6,
            1_000_000 * 1e6
        );
        console.log("Provided liquidity successfully");

        // Simulate transactions from JSON data
        string memory jsonData = vm.readFile("data/organized_uniswap_data.json");
        bytes memory parsedData = vm.parseJson(jsonData);
        
        uint256[] memory blockNumbers = abi.decode(parsedData, (uint256[]));
        string[] memory eventTypes = abi.decode(parsedData, (string[]));
        
        for (uint256 i = 0; i < blockNumbers.length; i++) {
            vm.roll(blockNumbers[i]);
            
            if (keccak256(abi.encodePacked(eventTypes[i])) == keccak256(abi.encodePacked("swaps"))) {
                simulateSwap(parsedData, i);
            } else if (keccak256(abi.encodePacked(eventTypes[i])) == keccak256(abi.encodePacked("mints"))) {
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