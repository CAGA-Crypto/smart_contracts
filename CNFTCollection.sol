// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CNFTCollection is ERC1155, Ownable {
    IERC20 public token;

    uint256 public constant GOLD = 1;
    uint256 public constant SILVER = 2;
    uint256 public constant BRONZE = 3;

    uint256 public tokensRequiredForGold = 20;
    uint256 public tokensRequiredForSilver = 10;
    uint256 public tokensRequiredForBronze = 5;

    constructor(address tokenAddress)
        ERC1155("")
        Ownable(msg.sender)
    {
        token = IERC20(tokenAddress);
    }

    function mintGold(address to) public {
        require(
            token.balanceOf(msg.sender) >= tokensRequiredForGold,
            "Not enough CAGA N tokens"
        );
        _mint(to, GOLD, 1, "");
    }

    function mintSilver(address to) public {
        require(
            token.balanceOf(msg.sender) >= tokensRequiredForSilver,
            "Not enough CAGA N tokens"
        );
        _mint(to, SILVER, 1, "");
    }

    function mintBronze(address to) public {
        require(
            token.balanceOf(msg.sender) >= tokensRequiredForBronze,
            "Not enough CAGA N tokens"
        );
        _mint(to, BRONZE, 1, "");
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }
}
