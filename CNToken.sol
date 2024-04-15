// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract CNToken is ERC20, Ownable, ERC20Permit {
    constructor(address initialOwner)
        ERC20("CAGA N Token", "CNT")
        Ownable(initialOwner)
        ERC20Permit("CAGA N Token")
    {
        _mint(msg.sender, 100000 * 10**decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        require(false, "Transfer is disabled");
        return false;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        require(false, "Transfer is disabled");
        return false;
    }
}
