// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./CPumpToken.sol";

contract TokenFactory {
    address public constant ROUTER = 0xf91D509a2b53bDEc334Be59d7050BDD2e0264fcA;
    event TokenCreated(address tokenAddress, address owner);

    function createToken(uint256 initialSupply, string memory _tokenName, string memory _tokenSymbol, uint256 tokenAmount) external payable returns (address) {
        require(msg.value > 0, "Must send ETH to create liquidity");

        CPumpToken newToken = new CPumpToken{value: msg.value}(initialSupply, _tokenName, _tokenSymbol, ROUTER, tokenAmount);
        newToken.transferOwnership(msg.sender);
        emit TokenCreated(address(newToken), msg.sender);
        return address(newToken);
    }
}
