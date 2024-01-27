// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts@5.0.0/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts@5.0.0/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts@5.0.0/access/Ownable.sol";


contract CagaStaking is Ownable {
    using SafeERC20 for IERC20;
    IERC20 public caga;
    //CAGA tokens will be allocated after mainnet launched
    mapping(address => uint256) public stakersBalances;
    address[] public stakers;
    event Staked(address indexed _addr, uint256 _amount);

    constructor(address _caga) Ownable(msg.sender){
        caga = IERC20(_caga);
    }

    function StakeCaga(uint256 _amount) public {
        caga.safeTransferFrom(msg.sender, address(this), _amount);
        if (stakersBalances[msg.sender] == 0) {
            stakers.push(msg.sender);
        }
        stakersBalances[msg.sender] += _amount;
        emit Staked(msg.sender, _amount);
    }

    function RedeemByOwner(uint256 _amount) public onlyOwner {
        caga.transfer(owner(), _amount);
    }
}