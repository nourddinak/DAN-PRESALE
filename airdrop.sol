// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title Airdrop
 * @dev A smart contract for managing a token airdrop on the Polygon network.
 * The owner can configure airdrop and referral amounts, and control the airdrop's lifecycle.
 */
contract Airdrop is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // The ERC20 token to be airdropped.
    IERC20 public token;

    // The amount of tokens each participant receives.
    uint256 public mainAirdropAmount;

    // The bonus amount for a successful referral.
    uint256 public referralBonusAmount;

    // The percentage fee for each claim, with 1000 representing 100%.
    // For example, a value of 20 would represent a 2% fee.
    uint256 public claimFeePercent;

    // A mapping to track which addresses have already claimed their airdrop.
    mapping(address => bool) public claimed;

    // The total amount of tokens allocated for this airdrop (excluding fees).
    uint256 public totalAirdropSupply;

    // The total amount of tokens that have been distributed to claimants and referrers.
    uint256 public tokensDistributed;

    // The maximum number of referrals allowed for a single user.
    uint256 public maxReferrals;

    // A mapping to track the number of successful referrals for each user.
    mapping(address => uint256) public referralCounts;

    // The timestamps for when the airdrop can start and stop.
    uint256 public startAirdropAt;
    uint256 public stopAirdropAt;

    // Events to log important actions.
    event AirdropClaimed(address indexed claimant, address indexed referrer);
    event AirdropStarted();
    event AirdropStopped();
    event TokensWithdrawn(address indexed owner, uint256 amount);
    event MainAirdropAmountUpdated(uint256 newAmount);
    event ReferralBonusAmountUpdated(uint256 newAmount);
    event AirdropFeeUpdated(uint256 newFee);
    event AirdropFeePaid(address indexed claimant, address indexed recipient, uint256 feeAmount);
    event TotalAirdropSupplyUpdated(uint256 newSupply);
    event MaxReferralsUpdated(uint256 newMax);
    event AirdropScheduleUpdated(uint256 startTimestamp, uint256 stopTimestamp);

    /**
     * @dev The constructor initializes the contract with the token address, airdrop amounts, and total supply.
     * @param _tokenAddress The address of the ERC20 token to be airdropped.
     * @param _initialMainAirdropAmount The initial amount of tokens for each participant.
     * @param _initialReferralBonusAmount The initial amount of tokens for each referral.
     * @param _initialClaimFeePercent The initial fee percentage (e.g., 20 for 2%).
     * @param _initialTotalAirdropSupply The initial total supply of tokens for the airdrop.
     */
    constructor(
        address _tokenAddress,
        uint256 _initialMainAirdropAmount,
        uint256 _initialReferralBonusAmount,
        uint256 _initialClaimFeePercent,
        uint256 _initialTotalAirdropSupply
    ) Ownable(msg.sender) {
        require(_tokenAddress != address(0), "Token address cannot be zero");
        token = IERC20(_tokenAddress);
        mainAirdropAmount = _initialMainAirdropAmount;
        referralBonusAmount = _initialReferralBonusAmount;
        claimFeePercent = _initialClaimFeePercent;
        totalAirdropSupply = _initialTotalAirdropSupply;
        maxReferrals = 500; // Default max referrals, can be changed by owner
    }

    /**
     * @dev Fallback function to handle any accidental Ether sent to the contract.
     * It simply reverts the transaction, preventing the ETH from being locked.
     */
    receive() external payable {
        revert("ETH not accepted");
    }

    /**
     * @dev Allows the owner to schedule the start and end of the airdrop.
     * @param _startTimestamp The timestamp for when the airdrop should start.
     * @param _stopTimestamp The timestamp for when the airdrop should stop.
     */
    function scheduleAirdrop(uint256 _startTimestamp, uint256 _stopTimestamp) public onlyOwner {
        require(_stopTimestamp > _startTimestamp, "Stop timestamp must be after start timestamp");
        startAirdropAt = _startTimestamp;
        stopAirdropAt = _stopTimestamp;
        emit AirdropScheduleUpdated(startAirdropAt, stopAirdropAt);
    }

    /**
     * @dev Allows the owner to change the main airdrop amount per participant.
     * @param _newAmount The new amount for the main airdrop.
     */
    function setMainAirdropAmount(uint256 _newAmount) public onlyOwner {
        mainAirdropAmount = _newAmount;
        emit MainAirdropAmountUpdated(_newAmount);
    }

    /**
     * @dev Allows the owner to change the referral bonus amount.
     * @param _newAmount The new amount for the referral bonus.
     */
    function setReferralBonusAmount(uint256 _newAmount) public onlyOwner {
        referralBonusAmount = _newAmount;
        emit ReferralBonusAmountUpdated(_newAmount);
    }

    /**
     * @dev Allows the owner to set the airdrop fee percentage.
     * @param _newFeePercent The new fee percentage (e.g., 20 for 2%).
     */
    function setClaimFeePercent(uint256 _newFeePercent) public onlyOwner {
        require(_newFeePercent <= 100, "Fee percentage cannot exceed 100%");
        claimFeePercent = _newFeePercent;
        emit AirdropFeeUpdated(_newFeePercent);
    }
    
    /**
     * @dev Allows the owner to set the total supply for the airdrop.
     * @param _newSupply The new total airdrop supply.
     */
    function setTotalAirdropSupply(uint256 _newSupply) public onlyOwner {
        // Prevent setting a supply less than what has already been distributed.
        require(_newSupply >= tokensDistributed, "New supply cannot be less than distributed tokens");
        totalAirdropSupply = _newSupply;
        emit TotalAirdropSupplyUpdated(_newSupply);
    }

    /**
     * @dev Allows the owner to set the maximum number of referrals per user.
     * @param _newMax The new maximum number of referrals.
     */
    function setMaxReferrals(uint256 _newMax) public onlyOwner {
        maxReferrals = _newMax;
        emit MaxReferralsUpdated(_newMax);
    }

    /**
     * @dev A function for a user to claim their airdrop without a referral.
     * It calls the main claim function with a zero address.
     */
    function claimAirdrop() public {
        claimAirdrop(address(0));
    }

    /**
     * @dev A function for a user to claim their airdrop.
     * This function also handles the referral bonus and a configurable fee.
     * @param _referrer The address of the referrer. Use address(0) if there is no referrer.
     */
    function claimAirdrop(address _referrer) public nonReentrant {
        // Checks
        require(!claimed[msg.sender], "You have already claimed your airdrop");
        require(block.timestamp >= startAirdropAt, "Airdrop has not started yet");
        require(block.timestamp < stopAirdropAt, "Airdrop has already ended");
        
        // Effects
        claimed[msg.sender] = true;

        // Interactions
        uint256 feeAmount = Math.mulDiv(mainAirdropAmount, claimFeePercent, 100);
        require(feeAmount <= mainAirdropAmount, "Invalid fee amount or airdrop amount");
        uint256 finalAirdropAmount = mainAirdropAmount - feeAmount;
        
        uint256 tokensToDistribute = finalAirdropAmount;

        // Handle referral bonus if a valid referrer is provided.
        if (_referrer != address(0)) {
            require(_referrer != msg.sender, "Cannot self-refer");
            require(_referrer != address(this), "Invalid referrer");
            
            // Requires the referrer to have already claimed their own airdrop to be eligible for a bonus.
            require(claimed[_referrer], "Referrer has not yet claimed");
            
            // Requires the referrer to be within their referral limit.
            require(referralCounts[_referrer] < maxReferrals, "Referrer has reached their referral limit");

            tokensToDistribute += referralBonusAmount;
            
            // Increment the referrer's count.
            referralCounts[_referrer]++;
        }

        require(tokensDistributed + tokensToDistribute <= totalAirdropSupply, "Total airdrop supply exhausted");
        
        // WARNING: For fee-on-transfer tokens, the contract's `balanceOf` may not reflect the actual amount received.
        // It's recommended to fund the contract with a buffer to account for these fees.
        require(token.balanceOf(address(this)) >= tokensToDistribute + feeAmount, "Insufficient token balance in contract");
        
        token.safeTransfer(owner(), feeAmount);
        emit AirdropFeePaid(msg.sender, owner(), feeAmount);

        tokensDistributed += tokensToDistribute;

        if (_referrer != address(0)) {
            token.safeTransfer(_referrer, referralBonusAmount);
        }
        
        token.safeTransfer(msg.sender, finalAirdropAmount);

        emit AirdropClaimed(msg.sender, _referrer);
    }

    /**
     * @dev Allows the owner to withdraw any remaining tokens from the contract.
     * This is useful after the airdrop has concluded or in an emergency.
     * @param _tokenAddress The address of the token to withdraw.
     */
    function withdrawTokens(address _tokenAddress) public onlyOwner {
        IERC20 _token = IERC20(_tokenAddress);
        uint256 balance = _token.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        _token.safeTransfer(owner(), balance);
        emit TokensWithdrawn(owner(), balance);
    }
}
