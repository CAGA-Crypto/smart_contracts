// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./IWETH9.sol";

contract InternalSwap is Ownable, ReentrancyGuard {
    IERC20 public userToken;
    IWETH9 public weth;
    IUniswapV2Router02 public uniswapRouter;
    address public uniswapPair;

    uint256 public reserveWeth;
    uint256 public reserveUserToken;
    uint256 public initialSupply;

    uint256 public feeBps;
    uint256 public minUserToken;
    uint256 public hardCap;

    mapping(address => uint256) public userTokenBalance;

    enum Reserve {WETH, UserToken}

    event AddLiquidity(Reserve typeReserve, uint256 value);
    event RemoveLiquidity(Reserve typeReserve, uint256 value);
    event Swap(uint256 weth, uint256 userToken, uint256 price, uint256 fee, address tokenAddress, address from);
    event TokenListed(address pair);

    constructor(
        address _userToken,
        address _weth,
        address _uniswapRouter,
        uint256 _feeBps,
        uint256 _minUserToken,
        uint256 _hardCap,
        uint256 _initialSupply
    ) Ownable(msg.sender) {
        userToken = IERC20(_userToken);
        weth = IWETH9(_weth);
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        feeBps = _feeBps;
        minUserToken = _minUserToken;
        hardCap = _hardCap;
        reserveUserToken = _initialSupply;
    }

    receive() external payable {}
    fallback() external payable {}

    function swapWethToUserToken(uint256 _wethIn) external nonReentrant {
        require(uniswapPair == address(0), "Token already listed on Uniswap");
        require(_wethIn != 0, "Pay WETH to get UserToken");

        (uint256 _outputUserToken, uint256 _price) = wethOverUserTokenValueAndPrice(0, _wethIn);

        require(_outputUserToken <= userToken.balanceOf(address(this)), "No liquidity");

        uint256 swFee = calculate(_outputUserToken);
        if (swFee < minUserToken) {
            swFee = minUserToken;
        }
        require(swFee <= _outputUserToken, "Fee more than output value");

        weth.transferFrom(msg.sender, address(this), _wethIn);
        userTokenBalance[msg.sender] += (_outputUserToken - swFee);
        reserveWeth += _wethIn;
        reserveUserToken -= _outputUserToken;

        emit Swap(_wethIn, _outputUserToken, _price, swFee, address(userToken), msg.sender);
    }

    function swapUserTokenToWeth(uint256 _userTokenIn) external nonReentrant {
        require(uniswapPair == address(0), "Token already listed on Uniswap");
        require(_userTokenIn != 0, "Pay UserToken to get WETH");

        uint256 swFee = calculate(_userTokenIn);
        if (swFee < minUserToken) {
            swFee = minUserToken;
        }

        require(swFee <= _userTokenIn, "Fee more than input value");

        uint256 userTokenInWithFee = _userTokenIn - swFee;
        (uint256 _outputWeth, uint256 _price) = wethOverUserTokenValueAndPrice(userTokenInWithFee, 0);
        
        require(_outputWeth <= weth.balanceOf(address(this)), "No liquidity");

        SafeERC20.safeTransferFrom(userToken, msg.sender, address(this), _userTokenIn);
        weth.transfer(msg.sender, _outputWeth);

        reserveUserToken += userTokenInWithFee;
        reserveWeth -= _outputWeth;

        emit Swap(_outputWeth, _userTokenIn, _price, swFee, address(userToken), msg.sender);
    }

    function mintUserToken() external nonReentrant {
        uint256 amount = userTokenBalance[msg.sender];
        require(amount > 0, "No user token balance to mint");
        userTokenBalance[msg.sender] = 0;
        userToken.transfer(msg.sender, amount);
    }

    function setMinBps(uint256 _newBps) external onlyOwner {
        feeBps = _newBps;
    }

    function setMinUserToken(uint256 _newUserToken) external onlyOwner {
        minUserToken = _newUserToken;
    }

    function addWethReserve(uint256 _wethIn) external payable onlyOwner {
        require(uniswapPair == address(0), "Token already listed on Uniswap");
        weth.transferFrom(msg.sender, address(this), _wethIn);
        reserveWeth += _wethIn;
        emit AddLiquidity(Reserve.WETH, _wethIn);
    }

    function addUserTokenReserve(uint256 _userTokenIn) external onlyOwner {
        require(uniswapPair == address(0), "Token already listed on Uniswap");
        require(userToken.allowance(msg.sender, address(this)) >= _userTokenIn, "UserToken allowance too low");
        SafeERC20.safeTransferFrom(userToken, msg.sender, address(this), _userTokenIn);
        reserveUserToken += _userTokenIn;
        emit AddLiquidity(Reserve.UserToken, _userTokenIn);
    }

    function removeWethReserve(uint256 _wethIn, bool _rebalance) external onlyOwner {
        require(_wethIn <= weth.balanceOf(address(this)), "No liquidity");
        weth.withdraw(_wethIn);
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

    function listToken(uint256 _wethAmount, uint256 _userTokenAmount, uint256 _amountAMin, uint256 _amountBMin) public onlyOwner {
        require(uniswapPair == address(0), "Token already listed on Uniswap");

        weth.approve(address(uniswapRouter), _wethAmount);

        userToken.approve(address(uniswapRouter), _userTokenAmount);

        // Add liquidity to Uniswap
        uniswapRouter.addLiquidity(
            address(weth),
            address(userToken),
            _wethAmount,
            _userTokenAmount,
            _amountAMin,
            _amountBMin,
            owner(),
            block.timestamp
        );

        address pair = IUniswapV2Factory(uniswapRouter.factory()).getPair(address(weth), address(userToken));
        require(pair != address(0), "Uniswap pair creation failed");
        uniswapPair = pair;

        emit TokenListed(pair);
    }
}
