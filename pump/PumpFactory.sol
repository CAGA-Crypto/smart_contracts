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
        uint256 initialSupply
    );

    constructor(address _weth, address _uniswapRouter) Ownable(msg.sender) {
        weth = _weth;
        uniswapRouter = _uniswapRouter;
    }

    function deployToken(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _initialSupply,
        string memory _twitter,
        string memory _telegram,
        string memory _website,
        string memory _imageUri
    ) internal returns (UserToken) {
        UserToken newToken = new UserToken(
            _tokenName,
            _tokenSymbol,
            _initialSupply,
            _twitter,
            _telegram,
            _website,
            _imageUri,
            msg.sender
        );
        return newToken;
    }

    function deployInternalSwap(
        address tokenAddress,
        uint256 _initialSupply,
        uint256 _feeBps,
        uint256 _minUserToken
    ) internal returns (InternalSwap) {
        InternalSwap newSwap = new InternalSwap(
            tokenAddress,
            weth,
            uniswapRouter,
            _feeBps,
            _initialSupply,
            _minUserToken
        );

        return newSwap;
    }

    function deployTokenAndInternalSwap(
        string memory _tokenName,
        string memory _tokenSymbol,
        string memory _twitter,
        string memory _telegram,
        string memory _website,
        string memory _imageUri,
        uint256 _initialSupply,
        uint256 _feeBps,
        uint256 _minUserToken,
        uint256 _wethIn
    ) external returns (address, address) {
        // Deploy new ERC20 token
        uint256 supply = _initialSupply;
        UserToken newToken = deployToken(
            _tokenName,
            _tokenSymbol,
            _initialSupply,
            _twitter,
            _telegram,
            _website,
            _imageUri
        );

        // Deploy new InternalSwap contract
        InternalSwap newSwap = deployInternalSwap(
            address(newToken),
            _initialSupply,
            _feeBps,
            _minUserToken
        );

        string memory name = _tokenName;
        string memory symbol = _tokenSymbol;

        emit InternalSwapDeployed(
            address(newSwap),
            address(newToken),
            msg.sender,
            name,
            symbol,
            supply
        );

        IWETH9 wethToken = IWETH9(weth);
        wethToken.approve(address(this), _wethIn);
        wethToken.approve(address(newSwap), _wethIn);
        wethToken.transferFrom(msg.sender, address(this), _wethIn);
        newSwap.addWethReserve(_wethIn);

        newToken.approve(address(this), supply);
        newToken.approve(address(newSwap), supply);
        newToken.transferFrom(address(this), address(newSwap), supply);
        mapTokensToSwap[address(newToken)] = address(newSwap);

        newSwap.transferOwnership(msg.sender);
        return (address(newToken), address(newSwap));
    }
}
