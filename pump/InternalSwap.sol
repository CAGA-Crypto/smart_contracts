// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts@4.9.0/access/Ownable.sol";
import "@openzeppelin/contracts@4.9.0/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts@4.9.0/security/ReentrancyGuard.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract InternalSwap is Ownable, ReentrancyGuard {
    IERC20 public userToken;
    IERC20 public weth;
    IUniswapV2Router02 public uniswapRouter;
    address public uniswapPair;

    uint256 public reserveWeth;
    uint256 public reserveUserToken;

    uint256 public feeBps;
    uint256 public minUserToken;

    enum Reserve {WETH, UserToken}

    event AddLiquidity(Reserve typeReserve, uint256 value);
    event RemoveLiquidity(Reserve typeReserve, uint256 value);
    event Swap(uint256 weth, uint256 userToken, uint256 price, uint256 fee);
    event TokenListed(address pair);

    constructor(
        address _userToken,
        address _weth,
        address _uniswapRouter,
        uint256 _feeBps,
        uint256 _minUserToken
    ) {
        userToken = IERC20(_userToken);
        weth = IERC20(_weth);
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        feeBps = _feeBps;
        minUserToken = _minUserToken;
    }

    receive() external payable {}
    fallback() external payable {}

    function swapWethToUserToken(uint256 _wethIn) external nonReentrant {
        require(_wethIn != 0, "Pay WETH to get UserToken");
        require(weth.allowance(msg.sender, address(this)) >= _wethIn, "WETH allowance too low");

        (uint256 _outputUserToken, uint256 _price) = wethOverUserTokenValueAndPrice(0, _wethIn);

        require(_outputUserToken <= userToken.balanceOf(address(this)), "No liquidity");

        uint256 swFee = calculate(_outputUserToken);
        if (swFee < minUserToken) {
            swFee = minUserToken;
        }

        require(swFee <= _outputUserToken, "Fee more than output value");

        SafeERC20.safeTransferFrom(weth, msg.sender, address(this), _wethIn);
        SafeERC20.safeTransfer(userToken, msg.sender, (_outputUserToken - swFee));
        reserveWeth += _wethIn;
        reserveUserToken -= _outputUserToken;

        emit Swap(_wethIn, _outputUserToken, _price, swFee);

        // Check if all user tokens are bought out
        if (reserveUserToken == 0 && uniswapPair == address(0)) {
            listToken(reserveWeth, reserveUserToken);
        }
    }

    function swapUserTokenToWeth(uint256 _userTokenIn) external nonReentrant {
        require(_userTokenIn != 0, "Pay UserToken to get WETH");
        require(userToken.allowance(msg.sender, address(this)) >= _userTokenIn, "UserToken allowance too low");

        uint256 swFee = calculate(_userTokenIn);
        if (swFee < minUserToken) {
            swFee = minUserToken;
        }

        require(swFee <= _userTokenIn, "Fee more than input value");

        uint256 userTokenInWithFee = _userTokenIn - swFee;
        (uint256 _outputWeth, uint256 _price) = wethOverUserTokenValueAndPrice(userTokenInWithFee, 0);
        
        require(_outputWeth <= weth.balanceOf(address(this)), "No liquidity");

        SafeERC20.safeTransferFrom(userToken, msg.sender, address(this), _userTokenIn);
        SafeERC20.safeTransfer(weth, msg.sender, _outputWeth);

        reserveUserToken += userTokenInWithFee;
        reserveWeth -= _outputWeth;

        emit Swap(_outputWeth, _userTokenIn, _price, swFee);
    }

    function setMinBps(uint256 _newBps) external onlyOwner {
        feeBps = _newBps;
    }

    function setMinUserToken(uint256 _newUserToken) external onlyOwner {
        minUserToken = _newUserToken;
    }

    function addWethReserve(uint256 _wethIn) external onlyOwner {
        require(weth.allowance(msg.sender, address(this)) >= _wethIn, "WETH allowance too low");
        SafeERC20.safeTransferFrom(weth, msg.sender, address(this), _wethIn);
        reserveWeth += _wethIn;
        emit AddLiquidity(Reserve.WETH, _wethIn);
    }

    function addUserTokenReserve(uint256 _userTokenIn) external onlyOwner {
        require(userToken.allowance(msg.sender, address(this)) >= _userTokenIn, "UserToken allowance too low");
        SafeERC20.safeTransferFrom(userToken, msg.sender, address(this), _userTokenIn);
        reserveUserToken += _userTokenIn;
        emit AddLiquidity(Reserve.UserToken, _userTokenIn);
    }

    function removeWethReserve(uint256 _wethIn, bool _rebalance) external onlyOwner {
        require(_wethIn <= weth.balanceOf(address(this)), "No liquidity");
        SafeERC20.safeTransfer(weth, msg.sender, _wethIn);
        if (_rebalance) {
            reserveWeth -= _wethIn;
            emit RemoveLiquidity(Reserve.WETH, _wethIn);
        }
    }

    function removeUserTokenReserve(uint256 _userTokenIn, bool _rebalance) external onlyOwner {
        require(_userTokenIn <= userToken.balanceOf(address(this)), "No liquidity");
        SafeERC20.safeTransfer(userToken, msg.sender, _userTokenIn);
        if (_rebalance) {
            reserveUserToken -= _userTokenIn;
            emit RemoveLiquidity(Reserve.UserToken, _userTokenIn);
        }
    }

    function getK() public view returns (uint256) {
        uint256 userTokenBal = reserveUserToken;
        uint256 wethBal = reserveWeth;
        uint256 k = userTokenBal * wethBal;
        return k;
    }

    function wethOverUserTokenValueAndPrice(uint256 _userTokenIn, uint256 _wethIn) public view returns (uint256, uint256) {
        uint256 userTokenBal = reserveUserToken;
        uint256 wethBal = reserveWeth;
        uint256 k = userTokenBal * wethBal;
        if (_userTokenIn > 0) {
            require(_wethIn == 0, "Estimate only for UserToken");
            uint256 tempUserToken = (_userTokenIn) + userTokenBal;
            uint256 newWethBal = k / tempUserToken;
            uint256 priceUserTokenToWeth = ((_userTokenIn) / (wethBal - newWethBal)) / 100;
            return ((wethBal - newWethBal), priceUserTokenToWeth);
        }
        if (_wethIn > 0) {
            require(_userTokenIn == 0, "Estimate only for WETH");
            uint256 tempWeth = (_wethIn) + wethBal;
            uint256 newUserTokenBal = k / tempWeth;
            uint256 priceUserTokenToWeth = ((userTokenBal - newUserTokenBal) / (_wethIn)) / 100;
            return ((userTokenBal - newUserTokenBal), priceUserTokenToWeth);
        }
        return (0, 0);
    }

    function calculate(uint256 amount) internal view returns (uint256) {
        return amount * feeBps / 10_000;
    }

    function listToken(uint256 _wethAmount, uint256 _userTokenAmount) internal {
        require(uniswapPair == address(0), "Token already listed on Uniswap");

        SafeERC20.safeApprove(weth, address(uniswapRouter), _wethAmount);
        SafeERC20.safeApprove(userToken, address(uniswapRouter), _userTokenAmount);

        // Add liquidity to Uniswap
        (uint256 amountWeth, uint256 amountUserToken, uint256 liquidity) = uniswapRouter.addLiquidity(
            address(weth),
            address(userToken),
            _wethAmount,
            _userTokenAmount,
            0,
            0,
            owner(),
            block.timestamp
        );


        address pair = IUniswapV2Factory(uniswapRouter.factory()).getPair(address(weth), address(userToken));
        require(pair != address(0), "Uniswap pair creation failed");
        uniswapPair = pair;

        emit TokenListed(pair);
    }
}
