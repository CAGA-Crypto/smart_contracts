// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUniswapV2Router02 {
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
    function WETH() external pure returns (address);
}

interface ICagaNFT {
    function mintNFT(address recipient, string memory tokenURI) external returns (uint256);
}

contract Buyer1 {
    address private owner;
    string private constant TOKEN_URI = "https://bafybeiabsldctdavd54nxazfh4ifiaubhhqs7mnpvvb5k6q4iw66wjed6y.ipfs.w3s.link/caganft.json";
    IUniswapV2Router02 public uniswapRouter;
    ICagaNFT public cagaNFT;

    event TokenPurchased(address indexed buyer, address indexed token, uint amountOutMin, uint ethValue, string tokenURI);

    constructor(address _router, address _nftContract) {
        owner = msg.sender;
        uniswapRouter = IUniswapV2Router02(_router);
        cagaNFT = ICagaNFT(_nftContract);
    }
    
    function buyToken(address token, uint amountOutMin) external payable {
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = token;

        uniswapRouter.swapExactETHForTokens{value: msg.value}(amountOutMin, path, msg.sender, block.timestamp + 20 minutes);
        
        cagaNFT.mintNFT(msg.sender, TOKEN_URI);

        emit TokenPurchased(msg.sender, token, amountOutMin, msg.value, TOKEN_URI);
    }

    function withdrawETH() external {
        require(msg.sender == owner, "Only the owner can withdraw");
        payable(owner).transfer(address(this).balance);
    }

    function getContractETHBalance() external view returns (uint) {
        return address(this).balance;
    }

    receive() external payable {}
}
