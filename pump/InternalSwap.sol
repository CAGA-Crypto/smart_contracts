// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./IWETH9.sol";

contract InternalSwap is Ownable {
    IERC20 public userToken;
    IWETH9 public weth;
    IUniswapV2Router02 public uniswapRouter;
    address public uniswapPair;
    address factory;

    uint256 public reserveWeth;
    uint256 public reserveUserToken;
    uint256 public initialSupply;

    uint256 public feeBps;
    uint256 public minUserToken;
    uint256 public hardCap;

    enum Reserve {WETH, UserToken}

    event AddLiquidity(Reserve typeReserve, uint256 value);
    event RemoveLiquidity(Reserve typeReserve, uint256 value);
    event Swap(string typeSwap, uint256 weth, uint256 userToken, uint256 price, uint256 fee, address tokenAddress, address from);
    event TokenListed(address pair);

    constructor(
        address _userToken,
        address _weth,
        address _uniswapRouter,
        uint256 _feeBps,
        uint256 _minUserToken,
        uint256 _hardCap,
        address _owner
    ) Ownable(_owner) {
        userToken = IERC20(_userToken);
        weth = IWETH9(_weth);
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        feeBps = _feeBps;
        minUserToken = _minUserToken;
        hardCap = _hardCap;
        factory = msg.sender;
    }

    receive() external payable {}
    fallback() external payable {}

    function swapWethToUserToken(uint256 _wethIn) external {
        require(_wethIn != 0, "Pay WETH to get UserToken");
        if (uniswapPair != address(0)) {
            swapWethToUserTokenUniswap(_wethIn);
        } else {
            (uint256 _outputUserToken, uint256 _price) = wethOverUserTokenValueAndPrice(0, _wethIn);

             require(_outputUserToken <= userToken.balanceOf(address(this)), "No liquidity");

            uint256 swFee = calculate(_outputUserToken);
            if (swFee < minUserToken) {
                swFee = minUserToken;
            }
            require(swFee <= _outputUserToken, "Fee more than output value");

            weth.transferFrom(msg.sender, address(this), _wethIn);
            SafeERC20.safeTransfer(userToken, msg.sender, (_outputUserToken-swFee));

            reserveWeth += _wethIn;
            reserveUserToken -= _outputUserToken;

            emit Swap("buy", _wethIn, _outputUserToken, _price, swFee, address(userToken), msg.sender);
        }
    }

    function swapWethToUserTokenUniswap(uint256 _wethIn) internal {
        if (weth.allowance(address(this), address(uniswapRouter)) < _wethIn) {
            weth.approve(address(uniswapRouter), weth.totalSupply());
        }
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(userToken);
        weth.transferFrom(msg.sender, address(this), _wethIn);
        uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(_wethIn, 0, path, msg.sender, block.timestamp + 20 minutes);
        uint256 _price = ((amounts[1]) / (amounts[0])) / 100;
        emit Swap("buy", amounts[0], amounts[1], _price, 0, address(userToken), msg.sender);
    }

    function swapUserTokenToWeth(uint256 _userTokenIn) external {
        require(_userTokenIn != 0, "Pay UserToken to get WETH");
        if (uniswapPair != address(0)) {
            swapUserTokenToWethUniswap(_userTokenIn);
        } else {
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

            emit Swap("sell", _outputWeth, _userTokenIn, _price, swFee, address(userToken), msg.sender);
        }
    }

    function swapUserTokenToWethUniswap(uint256 _userTokenIn) internal {
        if (userToken.allowance(address(this), address(uniswapRouter)) < _userTokenIn) {
            userToken.approve(address(uniswapRouter), userToken.totalSupply());
        }
        userToken.transferFrom(msg.sender, address(this), _userTokenIn);
        address[] memory path = new address[](2);
        path[0] = address(userToken);
        path[1] = address(weth);
        uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(_userTokenIn, 0, path, msg.sender, block.timestamp + 20 minutes);
        uint256 _price = ((amounts[0]) / (amounts[1])) / 100;
        emit Swap("sell", amounts[1], amounts[0], _price, 0, address(userToken), msg.sender);
    }

    function setMinBps(uint256 _newBps) external onlyOwner {
        feeBps = _newBps;
    }

    function setMinUserToken(uint256 _newUserToken) external onlyOwner {
        minUserToken = _newUserToken;
    }

    function addWethReserve(uint256 _wethIn) external payable {
        require(msg.sender == factory, "must be only from factory");
        require(uniswapPair == address(0), "Token already listed on Uniswap");
        weth.transferFrom(msg.sender, address(this), _wethIn);
        reserveWeth += _wethIn;
        emit AddLiquidity(Reserve.WETH, _wethIn);
    }

    function addUserTokenReserve(uint256 _userTokenIn) external {
        require(msg.sender == factory, "must be only from factory");
        require(uniswapPair == address(0), "Token already listed on Uniswap");
        require(userToken.allowance(msg.sender, address(this)) >= _userTokenIn, "UserToken allowance too low");
        SafeERC20.safeTransferFrom(userToken, msg.sender, address(this), _userTokenIn);
        reserveUserToken += _userTokenIn;
        emit AddLiquidity(Reserve.UserToken, _userTokenIn);
    }

    function removeWethReserve(uint256 _wethIn, bool _rebalance) external onlyOwner {
        require(_wethIn <= weth.balanceOf(address(this)), "No liquidity");
        require(uniswapPair == address(0), "Token already listed on Uniswap");
        weth.withdraw(_wethIn);
        if (_rebalance) {
            reserveWeth -= _wethIn;
            emit RemoveLiquidity(Reserve.WETH, _wethIn);
        }
    }

    function removeUserTokenReserve(uint256 _userTokenIn, bool _rebalance) external onlyOwner {
        require(_userTokenIn <= userToken.balanceOf(address(this)), "No liquidity");
        require(uniswapPair == address(0), "Token already listed on Uniswap");
        SafeERC20.safeTransfer(userToken, msg.sender, _userTokenIn);
        if (_rebalance) {
            reserveUserToken -= _userTokenIn;
            emit RemoveLiquidity(Reserve.UserToken, _userTokenIn);
        }
    }

    function getK() public view returns (uint256) {
        if (uniswapPair != address(0)) {
            uint256 wethAmount = weth.balanceOf(uniswapPair);
            uint256 userTokenAmount = userToken.balanceOf(uniswapPair);
            uint256 k = wethAmount * userTokenAmount;
            return k;
        } else {
            uint256 userTokenBal = reserveUserToken;
            uint256 wethBal = getVirtualWeth();
            uint256 k = userTokenBal * wethBal;
            return k;
        }
    }

    function wethOverUserTokenValueAndPrice(uint256 _userTokenIn, uint256 _wethIn) public view returns (uint256, uint256) {
        uint256 userTokenBal = 0;
        uint256 wethBal = 0;
        uint256 k = 0;
        if (uniswapPair != address(0)) {
            userTokenBal = userToken.balanceOf(uniswapPair);
            wethBal = weth.balanceOf(uniswapPair);
            k = userTokenBal * wethBal;
        } else {
            userTokenBal = reserveUserToken;
            wethBal = getVirtualWeth();
            k = userTokenBal * wethBal;
        }
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

    function getVirtualWeth() internal view returns(uint256) {
        return reserveWeth + 1 ether;
    }

    function calculate(uint256 amount) internal view returns (uint256) {
        return amount * feeBps / 10_000;
    }

    function listToken() public onlyOwner {
        require(uniswapPair == address(0), "Token already listed on Uniswap");
        uint256 wethAmount = weth.balanceOf(address(this));
        uint256 userTokenAmount = userToken.balanceOf(address(this));

        weth.approve(address(uniswapRouter), wethAmount);

        userToken.approve(address(uniswapRouter), userTokenAmount);

        // Add liquidity to Uniswap
        uniswapRouter.addLiquidity(
            address(weth),
            address(userToken),
            wethAmount,
            userTokenAmount,
            wethAmount,
            userTokenAmount,
            owner(),
            block.timestamp
        );

        address pair = IUniswapV2Factory(uniswapRouter.factory()).getPair(address(weth), address(userToken));
        require(pair != address(0), "Uniswap pair creation failed");
        uniswapPair = pair;

        uint256 v2token = IERC20(pair).balanceOf(address(this));
        if (v2token > 0) {
            IERC20(pair).transfer(address(0), v2token);
        }

        emit TokenListed(pair);
    }
}