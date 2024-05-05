// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract CNTSwap is Ownable {
    IERC20 public token;
    uint public swapRatio = 1 ether; // 1 CAGA to 1 CNT
    uint public cooldown = 24 hours;

    mapping(address => uint) public lastSwap;

    event Swapped(address indexed user, uint ethAmount, uint tokenAmount);
    event Withdrawn(address indexed to, uint ethAmount, uint tokenAmount);

    constructor(address _token) Ownable(msg.sender) {
        token = IERC20(_token);
    }


    function swap() public payable {
        require(block.timestamp >= lastSwap[msg.sender] + cooldown, "Cooldown period not yet passed");
        require(msg.value == swapRatio, "Incorrect amount of CAGA sent");
        require(token.balanceOf(address(this)) >= msg.value, "Insufficient token balance in the contract");

        lastSwap[msg.sender] = block.timestamp;

        token.transfer(msg.sender, msg.value);
        emit Swapped(msg.sender, msg.value, msg.value);
    }

    function withdraw(uint _cagaAmount, uint _tokenAmount) public onlyOwner {
        require(address(this).balance >= _cagaAmount, "Insufficient CAGA balance");
        require(token.balanceOf(address(this)) >= _tokenAmount, "Insufficient token balance");

        payable(msg.sender).transfer(_cagaAmount);
        token.transfer(msg.sender, _tokenAmount);
        emit Withdrawn(msg.sender, _cagaAmount, _tokenAmount);
    }

    function setCooldown(uint _newCooldown) public onlyOwner {
        cooldown = _newCooldown;
    }

    function setSwapRatio(uint _newRatio) public onlyOwner {
        swapRatio = _newRatio;
    }

    receive() external payable {}
}

