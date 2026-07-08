// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import "forge-std/Test.sol";
import "../src/SwapApp.sol";

contract SwapAppTest is Test {
    SwapApp app;
    address uniswapV2SwappRouterAddress = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address uniswapv2FactoryAddress = 0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9;
    address attacker = address(0x2);
    address user = 0xB45323118e29e3C33c4a906dD8ce9d9CF443D380; // Address with USDT in Arbitrum Mainnet
    address USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9; // USDT address in Arbitrum Mainnet
    address DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1; // DAI address in Arbitrum Mainnet

    
    function setUp() public {
        app = new SwapApp(uniswapV2SwappRouterAddress, uniswapv2FactoryAddress, USDT, DAI);
    }

    function test_Rescue_Unauthorized() public {
        vm.prank(attacker);
        vm.expectRevert();
        app.rescueERC20(USDT, 100);
    }

    function test_RemoveLiquidity_NoBalance() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(SwapApp.InsufficientBalance.selector, 1e18, 0));
        app.removeLiquidity(1e18, 0, 0, user, block.timestamp + 100);
    }

    function testFuzz_RemoveLiquidity_AccessControl(uint256 amount) public {
        vm.assume(amount > 0);
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(SwapApp.InsufficientBalance.selector, amount, 0));
        app.removeLiquidity(amount, 0, 0, attacker, block.timestamp + 100);
    }

    function test_SwapTokens_InsufficientFunds() public {
        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = DAI;
        
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(SwapApp.InsufficientBalance.selector, 1e6, 0));
        app.swapTokens(1e6, 0, path, user, block.timestamp + 100);
    }

    function testFuzz_AddLiquidity_Logic(uint256 amount) public {
        vm.assume(amount > 1e6 && amount < 1e18);
        deal(USDT, user, amount);
        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = DAI;

        vm.startPrank(user);
        IERC20(USDT).approve(address(app), amount);
        app.addLiquidity(amount, amount / 4, 0, path, 0, 0, block.timestamp + 100);
        
        assertGt(app.userLpBalances(user), 0);
        vm.stopPrank();
    }

    function test_RemoveLiquidity_Success() public {
        uint256 amount = 1000e6;
        deal(USDT, user, amount);
        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = DAI;

        vm.startPrank(user);
        IERC20(USDT).approve(address(app), amount);
        app.addLiquidity(amount, 100e6, 0, path, 0, 0, block.timestamp + 100);
        
        uint256 bal = app.userLpBalances(user);
        app.removeLiquidity(bal, 0, 0, user, block.timestamp + 100);
        
        assertEq(app.userLpBalances(user), 0);
        vm.stopPrank();
    }
    
    function test_RemoveLiquidity_UnauthorizedAccess() public {
        uint256 amount = 1000e6;
        deal(USDT, user, amount);
        address[] memory path = new address[](2);
        path[0] = USDT;
        path[1] = DAI;

        vm.startPrank(user);
        IERC20(USDT).approve(address(app), amount);
        app.addLiquidity(amount, 100e6, 0, path, 0, 0, block.timestamp + 100);
        vm.stopPrank();

        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(SwapApp.InsufficientBalance.selector, 1e18, 0));
        app.removeLiquidity(1e18, 0, 0, attacker, block.timestamp + 100);
    }
}
