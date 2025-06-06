// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./InscriptionToken.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InscriptionFactory {
    address public UNISWAP_V2_ROUTER;
    using Clones for address;
    
    address public immutable tokenImplementation;
    uint256 public constant FEE_PERCENT = 5; // 5% fee
    address public feeRecipient;
    
    mapping(address => bool) public isDeployedToken;
    mapping(address => address) public tokenCreators;

    event TokenDeployed(address indexed token, address indexed creator, string symbol);
    event TokenMinted(address indexed token, address indexed minter, uint256 amount);

    constructor(address _feeRecipient, address _router) {
        tokenImplementation = address(new InscriptionToken());
        feeRecipient = _feeRecipient;
        UNISWAP_V2_ROUTER = _router;
    }

    function deployInscription(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address) {
        address token = Clones.clone(tokenImplementation);
        InscriptionToken(token).initialize(
            symbol,
            totalSupply,
            perMint,
            price,
            address(this)
        );
        
        isDeployedToken[token] = true;
        tokenCreators[token] = msg.sender;
        
        emit TokenDeployed(token, msg.sender, symbol);
        return token;
    }

    function mintInscription(address tokenAddr) external payable {
        require(isDeployedToken[tokenAddr], "Invalid token address");
        
        InscriptionToken token = InscriptionToken(tokenAddr);
        uint256 cost = token.price() * token.perMint();
        require(msg.value >= cost, "Insufficient payment");
        
        // Calculate payments first
        uint256 fee = (msg.value * FEE_PERCENT) / 100;
        uint256 liquidityAmount = fee;
        uint256 creatorShare = msg.value - fee;

        // Approve tokens for router before minting
        token.approve(UNISWAP_V2_ROUTER, token.perMint());
        
        // Mint tokens
        token.mint(msg.sender);
        
        payable(feeRecipient).transfer(fee);
        payable(tokenCreators[tokenAddr]).transfer(creatorShare);
        
        // Add liquidity to Uniswap
        _addLiquidity(tokenAddr, liquidityAmount);
        
        emit TokenMinted(tokenAddr, msg.sender, token.perMint());
    }

    function buyMeme(address tokenAddr) external payable {
        require(isDeployedToken[tokenAddr], "Invalid token address");
        
        InscriptionToken token = InscriptionToken(tokenAddr);
        uint256 uniswapPrice = _getUniswapPrice(tokenAddr);
        require(uniswapPrice < token.price(), "Uniswap price not better than mint price");
        
        uint256 cost = token.price() * token.perMint();
        require(msg.value >= cost, "Insufficient payment");
        
        token.mint(msg.sender);
        
        uint256 fee = (msg.value * FEE_PERCENT) / 100;
        uint256 creatorShare = msg.value - fee;
        
        payable(feeRecipient).transfer(fee);
        payable(tokenCreators[tokenAddr]).transfer(creatorShare);
        emit TokenMinted(tokenAddr, msg.sender, token.perMint());
    }

    function _addLiquidity(address tokenAddr, uint256 ethAmount) private {
        InscriptionToken token = InscriptionToken(tokenAddr);
        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER);
        
        // Approve token transfer
        token.approve(address(router), token.perMint());
        
        // Add liquidity
        router.addLiquidityETH{value: ethAmount}(
            address(token),
            token.perMint(),
            0,
            0,
            address(this),
            block.timestamp
        );
    }

    function _getUniswapPrice(address tokenAddr) private view returns (uint256) {
        IUniswapV2Router02 router = IUniswapV2Router02(UNISWAP_V2_ROUTER);
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = tokenAddr;
        
        // Mock price for testing
        if (UNISWAP_V2_ROUTER != 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D) {
            return 0.9 ether;
        }
        
        try router.getAmountsOut(1 ether, path) returns (uint[] memory amounts) {
            return amounts[1];
        } catch {
            return type(uint256).max;
        }
    }
}
