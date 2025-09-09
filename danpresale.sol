// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title TokenPresale
 * @dev A smart contract for conducting a token presale on the Polygon network using MATIC.
 * The contract owner can manage the presale, including starting/stopping it, updating the price,
 * and withdrawing funds and unsold tokens.
 */
contract TokenPresale is Ownable, ReentrancyGuard {
    // The ERC20 token being sold in the presale
    IERC20 public myToken;

    // The price of one unit of the token for each tier, in a fixed-point representation
    mapping(uint256 => uint256) public tierPrices;
    
    // The total tokens to be sold in each tier
    mapping(uint256 => uint256) public tierTokenLimits;
    
    // The current active presale tier
    uint256 public currentTier;

    // Total number of tokens sold during the presale
    uint256 public totalTokensSold;

    // Total MATIC raised from the presale
    uint256 public totalMaticRaised;

    // Boolean to control the state of the presale (active or not)
    bool public presaleActive;

    // Address of the token to be sold
    address public immutable tokenAddress;
    
    // Minimum and maximum amount of MATIC a user can spend per purchase
    uint256 public minMaticBuy;
    uint256 public maxMaticBuy;

    // Variables for the two-step tier update process
    mapping(uint256 => uint256) private _proposedTierPrices;
    mapping(uint256 => uint256) private _proposedTierTokenLimits;
    uint256 public proposedTiersTimestamp;

    // A time delay of 24 hours for the tier update to prevent front-running
    uint256 public constant TIER_UPDATE_DELAY = 24 hours;

    // Events to log important actions
    event PresaleStarted();
    event PresaleStopped();
    event TiersProposed();
    event TiersUpdated();
    event BuyLimitsUpdated(uint256 newMin, uint256 newMax);
    event TokensPurchased(address indexed buyer, uint256 maticAmount, uint256 tokenAmount);
    event TokensDeposited(address indexed owner, uint256 amount);
    event RaisedMaticWithdrawn(address indexed owner, uint256 amount);
    event RemainingTokensWithdrawn(address indexed owner, uint256 amount);

    /**
     * @dev The constructor initializes the contract with the address of the token to be sold.
     * @param _tokenAddress The address of the ERC20 token.
     */
    constructor(address _tokenAddress) Ownable(msg.sender) {
        tokenAddress = _tokenAddress;
        myToken = IERC20(tokenAddress);

        // Set initial purchase limits.
        minMaticBuy = 1e18; // 1 MATIC
        maxMaticBuy = 100e18; // 100 MATIC
        presaleActive = false;
        currentTier = 1;
    }

    // --- Owner-specific functions ---

    /**
     * @dev Allows the owner to propose a new set of prices and token limits for each tier.
     * The changes will not take effect until the `commitTiers` function is called after a delay.
     * @param _proposedPrices An array of prices for each tier.
     * @param _proposedLimits An array of token limits for each tier.
     */
    function proposeTiers(uint256[] calldata _proposedPrices, uint256[] calldata _proposedLimits) external onlyOwner {
        require(_proposedPrices.length == _proposedLimits.length, "Arrays must have the same length");
        require(_proposedPrices.length > 0, "Tiers cannot be empty");
        
        for (uint i = 0; i < _proposedPrices.length; i++) {
            _proposedTierPrices[i + 1] = _proposedPrices[i];
            _proposedTierTokenLimits[i + 1] = _proposedLimits[i];
        }

        proposedTiersTimestamp = block.timestamp;
        
        emit TiersProposed();
    }

    /**
     * @dev Allows the owner to commit the proposed tiers after the required time delay.
     * The new tiers will then become active.
     */
    function commitTiers() external onlyOwner {
        require(proposedTiersTimestamp + TIER_UPDATE_DELAY <= block.timestamp, "Tier update is not ready yet");
        
        uint256 i = 1;
        while (_proposedTierPrices[i] > 0) {
            tierPrices[i] = _proposedTierPrices[i];
            tierTokenLimits[i] = _proposedTierTokenLimits[i];
            i++;
        }
        
        // Reset proposed tiers
        for (uint256 j = 1; j < i; j++) {
            _proposedTierPrices[j] = 0;
            _proposedTierTokenLimits[j] = 0;
        }

        emit TiersUpdated();
    }

    /**
     * @dev Allows the owner to start the presale.
     * Requires the presale to not be active.
     */
    function startPresale() external onlyOwner {
        require(!presaleActive, "Presale is already active");
        require(tierPrices[1] > 0, "Tiers must be configured and committed before starting the presale");
        presaleActive = true;
        emit PresaleStarted();
    }

    /**
     * @dev Allows the owner to stop the presale manually.
     * Requires the presale to be active.
     */
    function stopPresale() external onlyOwner {
        require(presaleActive, "Presale is not active");
        presaleActive = false;
        emit PresaleStopped();
    }
    
    /**
     * @dev Allows the owner to update the minimum and maximum MATIC a user can spend.
     * @param _minMaticBuy The new minimum MATIC buy amount.
     * @param _maxMaticBuy The new maximum MATIC buy amount.
     */
    function setMinMaxMaticBuy(uint256 _minMaticBuy, uint256 _maxMaticBuy) external onlyOwner {
        require(_minMaticBuy > 0, "Minimum buy must be greater than zero");
        require(_maxMaticBuy >= _minMaticBuy, "Maximum buy must be greater than or equal to minimum buy");
        minMaticBuy = _minMaticBuy;
        maxMaticBuy = _maxMaticBuy;
        emit BuyLimitsUpdated(_minMaticBuy, _maxMaticBuy);
    }

    /**
     * @dev Allows the owner to deposit tokens into the presale contract.
     * The owner must have already approved this contract to spend their tokens.
     * @param amount The number of tokens to deposit.
     */
    function depositTokensForSale(uint256 amount) external onlyOwner {
        // Transfer the tokens from the owner's address to this contract
        require(myToken.transferFrom(msg.sender, address(this), amount), "Token deposit failed");
        emit TokensDeposited(msg.sender, amount);
    }

    /**
     * @dev Allows the owner to withdraw the MATIC raised from the presale.
     * Requires the presale to be stopped.
     */
    function withdrawRaisedMatic() external onlyOwner {
        require(!presaleActive, "Presale must be stopped to withdraw funds");
        uint256 balance = address(this).balance;
        require(balance > 0, "No MATIC to withdraw");

        // Transfer MATIC to the owner's address
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Failed to withdraw MATIC");

        emit RaisedMaticWithdrawn(owner(), balance);
    }

    /**
     * @dev Allows the owner to withdraw any remaining unsold tokens.
     * This can be done at any time.
     */
    function withdrawRemainingTokens() external onlyOwner {
        uint256 remainingTokens = myToken.balanceOf(address(this));
        require(remainingTokens > 0, "No remaining tokens to withdraw");

        // Transfer the remaining tokens back to the owner's address
        require(myToken.transfer(owner(), remainingTokens), "Failed to withdraw remaining tokens");
        emit RemainingTokensWithdrawn(owner(), remainingTokens);
    }

    // --- Public/User functions ---

    /**
     * @dev Allows a user to buy tokens with MATIC.
     * This function is payable and can receive MATIC.
     */
    function buyTokens() public payable nonReentrant {
        require(presaleActive, "Presale is not active");
        require(tierPrices[currentTier] > 0, "Presale is complete, no more tiers available");
        require(msg.value >= minMaticBuy, "Amount must be greater than or equal to minimum purchase");
        require(msg.value <= maxMaticBuy, "Amount must be less than or equal to maximum purchase");

        // Calculate the number of tokens to sell based on the MATIC sent and current tier price.
        uint256 tokensToBuy = (msg.value * 1e18) / tierPrices[currentTier];
        uint256 tokensSoldInCurrentTier = totalTokensSold - tierTokenLimits[currentTier-1];
        require(tokensToBuy + tokensSoldInCurrentTier <= tierTokenLimits[currentTier], "Purchase exceeds current tier's limit");

        require(myToken.balanceOf(address(this)) >= tokensToBuy, "Not enough tokens in contract");

        // Transfer tokens to the buyer
        require(myToken.transfer(msg.sender, tokensToBuy), "Token transfer failed");

        // Update the total sold and MATIC raised counts
        totalTokensSold += tokensToBuy;
        totalMaticRaised += msg.value;

        // Check if the current tier is sold out and advance to the next tier
        if (totalTokensSold >= tierTokenLimits[currentTier]) {
            currentTier++;
        }

        // Emit the event to log the purchase
        emit TokensPurchased(msg.sender, msg.value, tokensToBuy);
    }

    /**
     * @dev Returns the total amount of MATIC raised during the presale.
     */
    function maticRaised() external view returns (uint256) {
        return totalMaticRaised;
    }

    /**
     * @dev Returns the number of unsold tokens remaining in the contract.
     */
    function tokensRemaining() external view returns (uint256) {
        return myToken.balanceOf(address(this)) - totalTokensSold;
    }

    /**
     * @dev Returns the current number of tokens per 1 MATIC.
     */
    function getCurrentPrice() external view returns (uint256) {
        return (1e36) / tierPrices[currentTier];
    }

    /**
     * @dev Fallback function that reverts, forcing users to use the `buyTokens` function.
     */
    receive() external payable {
        revert("Use buyTokens function");
    }
}
