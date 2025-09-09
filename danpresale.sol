// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title PreSale
 * @dev This contract manages a token presale on the Polygon network.
 * It allows users to purchase a specified ERC20 token using MATIC.
 * The contract owner has full control over the presale status, pricing,
 * and fund management.
 *
 * It is highly recommended to test this contract on a testnet (like Polygon Mumbai)
 * before deploying to the mainnet.
 */
contract PreSale is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // --- State Variables ---

    // The address of the token being sold in the presale.
    // User's token from the request: 0x46fc3e44a9dbbbb6b9abcd9c55b7f91037f16cffd
    IERC20Metadata public immutable token;

    // The price of the token, represented as the number of tokens
    // a user receives for 1 MATIC.
    uint256 public tokensPerMatic;

    // A flag to indicate whether the presale is currently active.
    bool public preSaleActive;

    // Total amount of MATIC raised during the presale.
    uint256 public totalMaticRaised;

    // A mapping to track the amount of tokens sold to each address.
    mapping(address => uint256) public tokensSoldTo;

    // Minimum and maximum MATIC amount per single buy transaction.
    uint256 public minMaticBuy;
    uint256 public maxMaticBuy;

    // --- Events ---

    event PresaleStarted();
    event PresaleEnded();
    event TokenPriceUpdated(uint256 newPrice);
    event TokensPurchased(address indexed buyer, uint256 maticAmount, uint256 tokenAmount);
    event MaticWithdrawn(address indexed to, uint256 amount);
    event UnsoldTokensWithdrawn(uint256 amount);
    event BuyLimitsUpdated(uint256 newMin, uint256 newMax);

    /**
     * @dev The constructor initializes the contract with the token address,
     * an initial price, and buy limits.
     * @param _tokenAddress The address of the ERC20 token to be sold.
     * @param _tokensPerMatic The initial price (tokens per 1 MATIC).
     * @param _minMaticBuy The minimum amount of MATIC for a purchase.
     * @param _maxMaticBuy The maximum amount of MATIC for a purchase.
     */
    constructor(
        address _tokenAddress,
        uint256 _tokensPerMatic,
        uint256 _minMaticBuy,
        uint256 _maxMaticBuy
    ) Ownable(msg.sender) {
        token = IERC20Metadata(_tokenAddress);
        tokensPerMatic = _tokensPerMatic;
        minMaticBuy = _minMaticBuy;
        maxMaticBuy = _maxMaticBuy;
        preSaleActive = false;
    }

    // --- Public Functions ---

    /**
     * @dev Allows users to purchase tokens using MATIC.
     * The `payable` modifier makes this function able to receive MATIC.
     * The `nonReentrant` modifier prevents reentrancy attacks.
     * Note: This function assumes the incoming MATIC has 18 decimals.
     */
    function buyTokens() external payable nonReentrant {
        // Ensure the presale is active
        require(preSaleActive, "Presale is not active");

        // Enforce buy limits
        require(msg.value >= minMaticBuy, "MATIC amount is below the minimum buy limit");
        require(msg.value <= maxMaticBuy, "MATIC amount exceeds the maximum buy limit");

        // Calculate the amount of tokens to send to the buyer, handling token decimals.
        // We use IERC20Metadata to get the token's decimals.
        uint256 tokenAmount = (msg.value * tokensPerMatic * (10 ** token.decimals())) / (10 ** 18);

        // Ensure the contract has enough tokens to fulfill the order.
        require(IERC20(address(token)).balanceOf(address(this)) >= tokenAmount, "Not enough tokens available for sale");

        // Record the MATIC raised and tokens sold
        totalMaticRaised += msg.value;
        tokensSoldTo[msg.sender] += tokenAmount;

        // Transfer the tokens to the buyer.
        IERC20(address(token)).safeTransfer(msg.sender, tokenAmount);

        // Emit an event to log the purchase.
        emit TokensPurchased(msg.sender, msg.value, tokenAmount);
    }

    // --- Owner-only Functions ---

    /**
     * @dev Allows the owner to start the presale.
     * Only callable if the presale is not already active.
     */
    function startPresale() external onlyOwner {
        require(!preSaleActive, "Presale is already active");
        preSaleActive = true;
        emit PresaleStarted();
    }

    /**
     * @dev Allows the owner to stop the presale.
     * Only callable if the presale is active.
     */
    function stopPresale() external onlyOwner {
        require(preSaleActive, "Presale is not active");
        preSaleActive = false;
        emit PresaleEnded();
    }

    /**
     * @dev Allows the owner to update the token price.
     * @param _newPrice The new price, representing tokens per 1 MATIC.
     */
    function setTokenPrice(uint256 _newPrice) external onlyOwner {
        tokensPerMatic = _newPrice;
        emit TokenPriceUpdated(_newPrice);
    }

    /**
     * @dev Allows the owner to set the minimum and maximum buy limits.
     * @param _newMin The new minimum MATIC buy limit.
     * @param _newMax The new maximum MATIC buy limit.
     */
    function setBuyLimits(uint256 _newMin, uint256 _newMax) external onlyOwner {
        require(_newMin <= _newMax, "Min buy must be less than or equal to max buy");
        minMaticBuy = _newMin;
        maxMaticBuy = _newMax;
        emit BuyLimitsUpdated(_newMin, _newMax);
    }

    /**
     * @dev Allows the owner to withdraw the collected MATIC.
     * This function transfers the entire MATIC balance of the contract to the owner.
     */
    function withdrawFunds() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No MATIC to withdraw");

        // Use a low-level call to handle the MATIC transfer safely.
        (bool sent,) = payable(owner()).call{value: balance}("");
        require(sent, "Failed to withdraw MATIC");
        emit MaticWithdrawn(owner(), balance);
    }

    /**
     * @dev Allows the owner to withdraw any unsold tokens from the contract.
     * This can be used after the presale has ended.
     */
    function withdrawUnsoldTokens() external onlyOwner {
        uint256 tokenBalance = IERC20(address(token)).balanceOf(address(this));
        require(tokenBalance > 0, "No tokens to withdraw");

        IERC20(address(token)).safeTransfer(owner(), tokenBalance);
        emit UnsoldTokensWithdrawn(tokenBalance);
    }
}
