// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract CagaNFT is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    mapping(address => bool) public approvedCallers;

    constructor() ERC721("Caga NFT", "CNFT") Ownable(msg.sender) {}

    function addApprovedCaller(address _caller) public onlyOwner {
        approvedCallers[_caller] = true;
    }

    function removeApprovedCaller(address _caller) public onlyOwner {
        approvedCallers[_caller] = false;
    }

    function mintNFT(address recipient, string memory tokenURI) external returns (uint256) {
        require(approvedCallers[msg.sender], "Caller is not approved to mint");
        
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }
}
