// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./CNToken.sol";

contract CNFTCollection is ERC1155, Ownable {
    CNToken public token;

    uint256 public constant GOLD = 1;
    uint256 public constant SILVER = 2;
    uint256 public constant BRONZE = 3;

    uint256 public tokensRequiredForGold = 20000000000000000000;
    uint256 public tokensRequiredForSilver = 10000000000000000000;
    uint256 public tokensRequiredForBronze = 5000000000000000000;

    constructor(address tokenAddress) ERC1155("") Ownable(msg.sender) {
        token = CNToken(tokenAddress);
    }

    function mintGold(address to) public {
        require(
            token.balanceOf(msg.sender) >= tokensRequiredForGold,
            "Not enough CAGA N tokens"
        );
        _mint(to, GOLD, 1, "");
        token.burn(msg.sender, tokensRequiredForGold);
    }

    function mintSilver(address to) public {
        require(
            token.balanceOf(msg.sender) >= tokensRequiredForSilver,
            "Not enough CAGA N tokens"
        );
        _mint(to, SILVER, 1, "");
        token.burn(msg.sender, tokensRequiredForSilver);
    }

    function mintBronze(address to) public {
        require(
            token.balanceOf(msg.sender) >= tokensRequiredForBronze,
            "Not enough CAGA N tokens"
        );
        _mint(to, BRONZE, 1, "");
        token.burn(msg.sender, tokensRequiredForBronze);
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }
}
