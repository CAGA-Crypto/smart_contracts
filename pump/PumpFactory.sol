// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts@4.9.0/access/Ownable.sol";
import "@openzeppelin/contracts@4.9.0/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts@4.9.0/token/ERC20/utils/SafeERC20.sol";
import "./InternalSwap.sol";
import "./UserToken.sol";

contract PumpFactory is Ownable {
    address public weth;
    address public uniswapRouter;

    event InternalSwapDeployed(address indexed swapContract, address indexed userToken, address indexed owner);
    event LiquidityProvided(address indexed swapContract, uint256 wethAmount, uint256 userTokenAmount);
    event TokenDeployed(address indexed tokenAddress, string name, string symbol, uint256 initialSupply);

    constructor(address _weth, address _uniswapRouter) {
        weth = _weth;
        uniswapRouter = _uniswapRouter;
    }

    function deployTokenAndInternalSwap(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _initialSupply,
        uint256 _feeBps,
        uint256 _minUserToken
    ) external onlyOwner returns (address, address) {
        // Deploy new ERC20 token
        UserToken newToken = new UserToken(_tokenName, _tokenSymbol, _initialSupply);
        emit TokenDeployed(address(newToken), _tokenName, _tokenSymbol, _initialSupply);

        // Deploy new InternalSwap contract
        InternalSwap newSwap = new InternalSwap(address(newToken), weth, uniswapRouter, _feeBps, _minUserToken);
        newSwap.transferOwnership(msg.sender);
        emit InternalSwapDeployed(address(newSwap), address(newToken), msg.sender);

        return (address(newToken), address(newSwap));
    }

    function provideLiquidity(
        address payable _swapContract,
        uint256 _wethAmount,
        uint256 _userTokenAmount
    ) external onlyOwner {
        InternalSwap swapContract = InternalSwap(_swapContract);
        IERC20 userToken = IERC20(swapContract.userToken());
        IERC20 wethToken = IERC20(swapContract.weth());

        require(userToken.allowance(msg.sender, address(this)) >= _userTokenAmount, "User token allowance too low");
        require(wethToken.allowance(msg.sender, address(this)) >= _wethAmount, "WETH allowance too low");

        SafeERC20.safeTransferFrom(userToken, msg.sender, address(swapContract), _userTokenAmount);
        SafeERC20.safeTransferFrom(wethToken, msg.sender, address(swapContract), _wethAmount);

        swapContract.addUserTokenReserve(_userTokenAmount);
        swapContract.addWethReserve(_wethAmount);

        emit LiquidityProvided(address(swapContract), _wethAmount, _userTokenAmount);
    }
}
