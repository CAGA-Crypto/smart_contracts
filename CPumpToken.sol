// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUniswapV2Router02 {
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

contract CPumpToken is ERC20, Ownable {
    uint256 public reserveETH;
    uint256 public reserveToken;
    bool public isListed;
    address public uniswapRouter;
    mapping(address => uint256) public purchasedTokens;

    event TokenListed();

    constructor(
        uint256 initialSupply,
        string memory _tokenName,
        string memory _tokenSymbol,
        address _uniswapRouter,
        uint256 tokenAmount
    ) ERC20(_tokenName, _tokenSymbol) Ownable(msg.sender) payable {
        require(msg.value > 0, "Must send CAGA to create liquidity");

        _mint(msg.sender, initialSupply);

        uniswapRouter = _uniswapRouter;

        // Add initial liquidity to the internal pool
        _transfer(msg.sender, address(this), tokenAmount);
        reserveETH = msg.value;
        reserveToken = tokenAmount;
    }

    function addLiquidity(uint256 tokenAmount) external payable onlyOwner {
        require(!isListed, "Token is already listed");
        _transfer(msg.sender, address(this), tokenAmount);
        reserveETH += msg.value;
        reserveToken += tokenAmount;
    }

    function getPrice(uint256 tokenAmount) public view returns (uint256) {
        require(reserveETH > 0 && reserveToken > 0, "No liquidity");
        return (tokenAmount * reserveETH) / reserveToken;
    }

    function getPricePerToken() public view returns (uint256) {
        return getPrice(1e18); // Assuming token has 18 decimals
    }

    function buyToken() external payable {
        require(!isListed, "Token is already listed");
        uint256 amountToBuy = msg.value * reserveToken / reserveETH;
        uint256 excessETH = msg.value;

        if (amountToBuy > reserveToken) {
            amountToBuy = reserveToken;
        }

        excessETH -= (amountToBuy * reserveETH / reserveToken);

        require(amountToBuy > 0, "Insufficient liquidity");

        reserveETH += msg.value - excessETH;
        reserveToken -= amountToBuy;
        purchasedTokens[msg.sender] += amountToBuy;

        if (excessETH > 0) {
            payable(msg.sender).transfer(excessETH);
        }

        // Check if all tokens are sold out
        if (reserveToken == 0) {
            _listOnUniswap();
        }
    }

    function _listOnUniswap() internal {
        require(!isListed, "Already listed");
        isListed = true;

        IUniswapV2Router02 uniswapRouterInstance = IUniswapV2Router02(uniswapRouter);
        _approve(address(this), address(uniswapRouterInstance), reserveToken);

        uniswapRouterInstance.addLiquidityETH{value: reserveETH}(
            address(this),
            reserveToken,
            0,
            0,
            owner(),
            block.timestamp
        );

        reserveETH = 0;
        reserveToken = 0;

        emit TokenListed();
    }

    function mintPurchasedTokens() external {
        require(isListed, "Token is not listed yet");
        uint256 amount = purchasedTokens[msg.sender];
        require(amount > 0, "No tokens to mint");
        purchasedTokens[msg.sender] = 0;
        _mint(msg.sender, amount);
    }
}
