// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./InternalSwap.sol";
import "./UserToken.sol";
import "./IWETH9.sol";

contract PumpFactory is Ownable {
    address public weth;
    address public uniswapRouter;
    mapping(address => address) public mapTokensToSwap;

    event InternalSwapDeployed(
        address indexed swapContract,
        address indexed userToken,
        address indexed owner,
        string name,
        string symbol,
        uint256 initialSupply,
        string twitter,
        string telegram,
        string website,
        string imageUri,
        address from
    );

    error AllowanceTooLow(address token, uint256 required, uint256 available);

    constructor(address _weth, address _uniswapRouter) Ownable(msg.sender) {
        weth = _weth;
        uniswapRouter = _uniswapRouter;
    }

    function deployToken(
        string calldata name,
        string calldata symbol,
        uint256 initialSupply,
        string calldata _twitter,
        string calldata _telegram,
        string calldata _website,
        string calldata _imageUri,
        address _from
    ) internal returns (UserToken) {
        UserToken newToken = new UserToken(
            name,
        symbol,
        initialSupply,
        _twitter,
        _telegram,
        _website,
        _imageUri,
        _from
        );
        return newToken;
    }

    function deployInternalSwap(
        address tokenAddress,
        uint256 _feeBps,
        uint256 _minUserToken,
        uint256 _hardCap
    ) internal returns (InternalSwap) {
        InternalSwap newSwap = new InternalSwap(
            tokenAddress,
            weth,
            uniswapRouter,
            _feeBps,
            _minUserToken,
            _hardCap,
            owner()
        );
        return newSwap;
    }

    function deployTokenAndInternalSwap(
        string calldata _tokenName,
        string calldata _tokenSymbol,
        string calldata _twitter,
        string calldata _telegram,
        string calldata _website,
        string calldata _imageUri,
        uint256 _initialSupply,
        uint256 _feeBps,
        uint256 _minUserToken,
        uint256 _hardCap,
        uint256 _liquidityToAdd
    ) external returns (address, address) {
        if (_liquidityToAdd > 0) {
            require(IERC20(weth).balanceOf(msg.sender) >= _liquidityToAdd, "not enough balance");
            require(IERC20(weth).allowance(msg.sender, address(this)) >= _liquidityToAdd, "no allowance");
        }

        UserToken newToken = deployToken(
            _tokenName,
            _tokenSymbol,
            _initialSupply,
            _twitter,
            _telegram,
            _website,
            _imageUri,
            msg.sender
        );
        // Deploy new InternalSwap contract
        InternalSwap newSwap = deployInternalSwap(
            address(newToken),
            _feeBps,
            _minUserToken,
            _hardCap
        );

        emit InternalSwapDeployed(
            address(newSwap),
            address(newToken),
            msg.sender,
            _tokenName,
            _tokenSymbol,
            _initialSupply,
            _twitter,
            _telegram,
            _website,
            _imageUri,
            msg.sender
        );

        newToken.approve(address(this), _initialSupply);
        newToken.approve(address(newSwap), _initialSupply);
        mapTokensToSwap[address(newToken)] = address(newSwap);

        if (_liquidityToAdd > 0) {
            IERC20(weth).transferFrom(msg.sender, address(this),_liquidityToAdd);
            IERC20(weth).approve(address(newSwap),_liquidityToAdd);
            newSwap.addWethReserve(_liquidityToAdd);
            uint256 k = _initialSupply * _liquidityToAdd;
            uint256 tempWeth = _liquidityToAdd;
            uint256 newUserTokenBal = k / tempWeth;
            uint256 tokenToSend = _initialSupply - newUserTokenBal;
            newToken.transfer(msg.sender, tokenToSend);
            newSwap.addUserTokenReserve(_initialSupply-tokenToSend);
        } else {
            newSwap.addUserTokenReserve(_initialSupply);
        }

        return (address(newToken), address(newSwap));
    }
}