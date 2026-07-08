// SPDX-License-Identifier: MIT
pragma solidity 0.8.35;

import "./interfaces/IV2Router02.sol";
import "./interfaces/IFactory.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract SwapApp is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    address public immutable V2Router02Address;
    address public immutable UniswapFactoryAddress;
    address public immutable USDT;
    address public immutable DAI;
    address public immutable LP_TOKEN;

    error InsufficientBalance(uint256 requested, uint256 available);

    mapping(address => uint256) public userLpBalances;

    event SwapTokens(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event AddLiquidity(address indexed user, uint256 lpTokenAmount);
    event RemoveLiquidity(address indexed user, uint256 lpTokenAmount);

    constructor(address _router, address _factory, address _usdt, address _dai) Ownable(msg.sender) {
        V2Router02Address = _router;
        UniswapFactoryAddress = _factory;
        USDT = _usdt;
        DAI = _dai;
        LP_TOKEN = IFactory(_factory).getPair(_usdt, _dai);
    }

    function swapTokens(uint256 amountIn_, uint256 amountOutMin_, address[] calldata path_, address to_, uint256 deadline_) public nonReentrant returns (uint256) {
        uint256 balance = IERC20(path_[0]).balanceOf(msg.sender);
        if (balance < amountIn_) {
            revert InsufficientBalance(amountIn_, balance);
        }
        IERC20(path_[0]).safeTransferFrom(msg.sender, address(this), amountIn_);
        IERC20(path_[0]).forceApprove(V2Router02Address, amountIn_);
        
        uint[] memory amounts = IV2Router02(V2Router02Address).swapExactTokensForTokens(amountIn_, amountOutMin_, path_, to_, deadline_);
        uint256 amountOut = amounts[amounts.length - 1];
        
        emit SwapTokens(path_[0], path_[path_.length - 1], amountIn_, amountOut);
        return amountOut;
    }

    function addLiquidity(uint256 amountIn_, uint256 amountSwap_, uint256 amountOutMin_, address[] calldata path_, uint256 amountAMin_, uint256 amountBMin_, uint256 deadline_) external nonReentrant {
        IERC20(USDT).safeTransferFrom(msg.sender, address(this), amountIn_);
        
        uint256 swappedAmount = swapTokens(amountSwap_, amountOutMin_, path_, address(this), deadline_);
        uint256 usdtRemaining = amountIn_ - amountSwap_;
        
        IERC20(USDT).forceApprove(V2Router02Address, usdtRemaining);
        IERC20(DAI).forceApprove(V2Router02Address, swappedAmount);

        (,,uint256 lpTokenAmount) = IV2Router02(V2Router02Address).addLiquidity(USDT, DAI, usdtRemaining, swappedAmount, amountAMin_, amountBMin_, address(this), deadline_);

        userLpBalances[msg.sender] += lpTokenAmount;

        emit AddLiquidity(msg.sender, lpTokenAmount);
    }

    function removeLiquidity(uint256 liquidityAmount_, uint256 amountAMin_, uint256 amountBMin_, address to_, uint256 deadline_) external nonReentrant {
 
        uint256 userBalance = userLpBalances[msg.sender];
        if (userBalance < liquidityAmount_) {
            revert InsufficientBalance(liquidityAmount_, userBalance);
        }

        userLpBalances[msg.sender] -= liquidityAmount_;

        IERC20(LP_TOKEN).forceApprove(V2Router02Address, liquidityAmount_);
        IV2Router02(V2Router02Address).removeLiquidity(USDT, DAI, liquidityAmount_, amountAMin_, amountBMin_, to_, deadline_);

        emit RemoveLiquidity(msg.sender, liquidityAmount_);
    }

    function rescueERC20(address token_, uint256 amount_) external onlyOwner {
        IERC20(token_).safeTransfer(msg.sender, amount_);
    }
}
