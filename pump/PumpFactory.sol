// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./InternalSwap.sol";
import "./UserToken.sol";
import "./IWETH9.sol";

contract PumpFactory is Ownable {
    uint256 public fee; //fee in weth
    address public weth;
    address public uniswapRouter;
    address public benefeciary;
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

    constructor(address _weth, address _uniswapRouter, uint256 _fee, address _benefeciary) Ownable(msg.sender) {
        weth = _weth;
        uniswapRouter = _uniswapRouter;
        fee = _fee;
        benefeciary = _benefeciary;
    }

    function changeFee(uint256 _newFee) public onlyOwner {
        fee = _newFee;
    }

    function deposit() public payable {
        uint256 val = msg.value ;
        IWETH9(weth).deposit{ value: msg.value }();
        IWETH9(weth).transfer(msg.sender, val);
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
        address tokenAddress
    ) internal returns (InternalSwap) {
        InternalSwap newSwap = new InternalSwap(
            tokenAddress,
            weth,
            uniswapRouter,
            owner(),
            benefeciary
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
        uint256 _liquidityToAdd
    ) external payable returns (address, address) {
        uint256 _initialSupply = 1000000000 * 10 ** 18;
        bool noNeed = false;
        require(msg.value >= _liquidityToAdd + fee);
        uint256 val = msg.value ;
        IWETH9(weth).deposit{ value: msg.value }();
        IWETH9(weth).transfer(address(this), val);
        noNeed = true;
        IERC20(weth).transferFrom(address(this), benefeciary,fee); 

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
            address(newToken)
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

        newSwap.addUserTokenReserve(_initialSupply);
        if (_liquidityToAdd > 0) {
            if (!noNeed) {
                IERC20(weth).transferFrom(msg.sender, address(this),_liquidityToAdd);
            }
            IERC20(weth).approve(address(newSwap),_liquidityToAdd);
            newSwap.swapWethToUserToken(_liquidityToAdd);
            uint256 balanceNow = newToken.balanceOf(address(this));
            newToken.transfer(msg.sender, balanceNow);
        }

        return (address(newToken), address(newSwap));
    }

    function changeBenefeciary(address _benefeciary) public onlyOwner {
        benefeciary = _benefeciary;
    }
}