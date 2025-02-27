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
    address public benefeciary;
    uint256 public feeBps;
    address factory;

    uint256 public reserveWeth;
    uint256 public reserveUserToken;
    uint256 public initialSupply;

    enum Reserve {WETH, UserToken}

    event AddLiquidity(Reserve typeReserve, uint256 value);
    event RemoveLiquidity(Reserve typeReserve, uint256 value);
    event Swap(string typeSwap, uint256 weth, uint256 userToken, uint256 price, address tokenAddress, address from);
    event TokenListed(address pair);

    constructor(
        address _userToken,
        address _weth,
        address _uniswapRouter,
        address _owner,
        address _benefeciary
    ) Ownable(_owner) {
        userToken = IERC20(_userToken);
        weth = IWETH9(_weth);
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        factory = msg.sender;
        feeBps = 100;
        benefeciary = _benefeciary;
    }

    receive() external payable {}
    fallback() external payable {}

    function swapWethToUserToken(uint256 _wethIn) external payable {
        require(_wethIn != 0, "Pay WETH to get UserToken");
        require(msg.value >= _wethIn);
        uint256 val = msg.value ;
        weth.deposit{ value: msg.value }();
        weth.transfer(address(this), val);
        if (uniswapPair != address(0)) {
            swapWethToUserTokenUniswap(_wethIn);
        } else {
            uint256 swFee = calculate(_wethIn);
            uint256 wethMinusFee = _wethIn - swFee;
            (uint256 _outputUserToken, uint256 _price) = wethOverUserTokenValueAndPrice(0, wethMinusFee, false);

            require(_outputUserToken <= userToken.balanceOf(address(this)), "No liquidity");

            SafeERC20.safeTransfer(userToken, msg.sender, (_outputUserToken));

            reserveWeth += wethMinusFee;
            reserveUserToken -= _outputUserToken;

            weth.transfer(benefeciary, swFee);

            emit Swap("buy", wethMinusFee, _outputUserToken, _price, address(userToken), msg.sender);
        }
    }

    function swapWethToUserTokenUniswap(uint256 _wethIn) internal {
        if (weth.allowance(address(this), address(uniswapRouter)) < _wethIn) {
            weth.approve(address(uniswapRouter), weth.totalSupply());
        }
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(userToken);
        uint out = getAmountsOutWethIn(_wethIn);
        uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(_wethIn, out, path, msg.sender, block.timestamp + 20 minutes);
        uint256 _price = ((amounts[1]) / (amounts[0])) / 100;
        emit Swap("buy", amounts[0], amounts[1], _price, address(userToken), msg.sender);
    }

    function swapUserTokenToWeth(uint256 _userTokenIn) external {
        require(_userTokenIn != 0, "Pay UserToken to get WETH");
        if (uniswapPair != address(0)) {
            swapUserTokenToWethUniswap(_userTokenIn);
        } else {
            (uint256 _outputWeth, uint256 _price) = wethOverUserTokenValueAndPrice(_userTokenIn, 0, false);
        
            require(_outputWeth <= weth.balanceOf(address(this)), "No liquidity");
            weth.withdraw(_outputWeth);
            SafeERC20.safeTransferFrom(userToken, msg.sender, address(this), _userTokenIn);
            uint256 swFee = calculate(_outputWeth);
            uint256 wethMinusFee = _outputWeth - swFee;

            payable(msg.sender).transfer(wethMinusFee);

            reserveUserToken += _userTokenIn;
            reserveWeth -= _outputWeth;
            payable(benefeciary).transfer(swFee);

            emit Swap("sell", wethMinusFee, _userTokenIn, _price, address(userToken), msg.sender);
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
        uint out = getAmountsOutTokenIn(_userTokenIn);
        uint[] memory amounts = uniswapRouter.swapExactTokensForETH(_userTokenIn, out, path, msg.sender, block.timestamp + 20 minutes);
        uint256 _price = ((amounts[0]) / (amounts[1])) / 100;
        emit Swap("sell", amounts[1], amounts[0], _price, address(userToken), msg.sender);
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
        weth.transfer(owner(), _wethIn);
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

    function wethOverUserTokenValueAndPrice(uint256 _userTokenIn, uint256 _wethIn, bool _isUniswap) internal view returns (uint256, uint256) {
        uint256 noMore = 200000000000000000000000000;
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
            k = getK();
        }
        if (_userTokenIn > 0) {
            require(_wethIn == 0, "Estimate only for UserToken");
            uint256 tempUserToken = (_userTokenIn) + userTokenBal;
            uint256 newWethBal = k / tempUserToken;
            uint256 estimation = wethBal - newWethBal;
            if (estimation > reserveWeth) {
                estimation = reserveWeth;
            }
            uint256 priceUserTokenToWeth = ((_userTokenIn) / estimation) / 100;
            return (estimation, priceUserTokenToWeth);
        }
        if (_wethIn > 0) {
            require(_userTokenIn == 0, "Estimate only for WETH");
            uint256 tempWeth = (_wethIn) + wethBal;
            uint256 newUserTokenBal = k / tempWeth;
            uint256 estimation = userTokenBal - newUserTokenBal;
            if (!_isUniswap) {
                require((reserveUserToken - noMore) >= estimation, "cannot buy more 80%");
            }
            uint256 priceUserTokenToWeth = (estimation / (_wethIn)) / 100;
            return (estimation, priceUserTokenToWeth);
        }
        return (0, 0);
    }

    function wethOverUserTokenValueAndPriceFee(uint256 _userTokenIn, uint256 _wethIn) public view returns (uint256, uint256) {
        bool isUniswap = false;
        if (uniswapPair != address(0)) {
            isUniswap = true;
        }
        if (_userTokenIn > 0) {
            require(_wethIn == 0, "Estimate only for UserToken");
            (uint256 value, uint256 price) = wethOverUserTokenValueAndPrice(_userTokenIn, _wethIn, isUniswap);
            uint256 swFee = calculate(value);
            uint256 wethMinusFee = value - swFee;
            return (wethMinusFee, price);
        }
        if (_wethIn > 0) {
            require(_userTokenIn == 0, "Estimate only for WETH");
            uint256 swFee = calculate(_wethIn);
            uint256 wethMinusFee = _wethIn - swFee;
            return  wethOverUserTokenValueAndPrice(_userTokenIn, wethMinusFee, isUniswap);
        }
        return (0,0);
    }

    function getVirtualWeth() internal view returns(uint256) {
        //return reserveWeth + 5210000000000000000 wei;
        return reserveWeth + 1 ether;
    }

    function setMinBps(uint256 _newBps) external onlyOwner {
        feeBps = _newBps;
    }

    function listToken() public onlyOwner {
        require(uniswapPair == address(0), "Token already listed on Uniswap");
        uint256 benFee = 80000000000000000; //base
       // uint256 benFee = 400000000000000000; //bnb
        uint256 wethAmount = weth.balanceOf(address(this)) - benFee;
        uint256 userTokenAmount = userToken.balanceOf(address(this));

        weth.approve(address(uniswapRouter), wethAmount);

        weth.transfer(benefeciary, benFee);

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

    function calculate(uint256 amount) internal view returns (uint256) {
        return amount * feeBps / 10_000;
    }

    function changeFee(uint256 _newFee) public onlyOwner {
        feeBps = _newFee;
    }

    function changeBenefeciary(address _benefeciary) public onlyOwner {
        benefeciary = _benefeciary;
    }

    function getAmountsOutWethIn(uint amountIn) internal view returns (uint) {
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(userToken);
        uint[] memory amounts = uniswapRouter.getAmountsOut(amountIn, path);
        return amounts[1] * 9_000 / 10_000;
    }

    function getAmountsOutTokenIn(uint amountIn) internal view returns (uint) {
        address[] memory path = new address[](2);
        path[0] = address(userToken);
        path[1] = address(weth);
        uint[] memory amounts = uniswapRouter.getAmountsOut(amountIn, path);
        return amounts[1] * 9_000 / 10_000;
    }
}