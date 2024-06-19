// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract UserToken is ERC20 {
    string public twitter;
    string public telegram;
    string public website;
    string public imageUri;
    address public from;

    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        string memory _twitter,
        string memory _telegram,
        string memory _website,
        string memory _imageUri,
        address _from
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
        
        twitter = _twitter;
        telegram = _telegram;
        website = _website;
        imageUri = _imageUri;
        from = _from;
    }
}
