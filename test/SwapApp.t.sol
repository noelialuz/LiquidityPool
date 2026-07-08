// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import "forge-std/Test.sol";
import "../src/SwapApp.sol";

contract SwappAppTest is Test {
    SwapApp app;
    address router = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
    address factory = 0xf1D7CC64Fb4452F05c498126312eBE29f30Fbcf9;
    address user = 0xB45323118e29e3C33c4a906dD8ce9d9CF443D380;
    address USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

    function setUp() public {
        app = new SwapApp(router, factory, USDT, DAI);
    }

    function testRescueFunction() public {
        vm.prank(user);
        IERC20(USDT).transfer(address(app), 1e6);
        
        uint256 balBefore = IERC20(USDT).balanceOf(address(this));
        app.rescueERC20(USDT, 1e6);
        assertGt(IERC20(USDT).balanceOf(address(this)), balBefore);
    }
}