// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

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

    // A flag to activate or deactivate the airdrop.
    bool public isAirdropActive;

    // A mapping to track which addresses have already claimed their airdrop.
    mapping(address => bool) public claimed;

    // The total amount of tokens allocated for this airdrop (excluding fees).
    uint256 public totalAirdropSupply;

    // The total amount of tokens that have been distributed to claimants and referrers.
    uint256 public tokensDistributed;

    // The Merkle root of the whitelist for valid referrers.
    bytes32 public merkleRoot;

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
    event MerkleRootUpdated(bytes32 newRoot);

    /**
     * @dev The constructor initializes the contract with the token address, airdrop amounts, and total supply.
     * @param _tokenAddress The address of the ERC20 token to be airdropped.
     * @param _initialMainAirdropAmount The initial amount of tokens for each participant.
     * @param _initialReferralBonusAmount The initial amount of tokens for each referral.
     * @param _initialClaimFeePercent The initial fee percentage (e.g., 20 for 2%).
     * @param _initialTotalAirdropSupply The initial total supply of tokens for the airdrop.
     * @param _initialMerkleRoot The initial Merkle root for the referral whitelist.
     */
    constructor(
        address _tokenAddress,
        uint256 _initialMainAirdropAmount,
        uint256 _initialReferralBonusAmount,
        uint256 _initialClaimFeePercent,
        uint256 _initialTotalAirdropSupply,
        bytes32 _initialMerkleRoot
    ) Ownable(msg.sender) {
        require(_tokenAddress != address(0), "Token address cannot be zero");
        token = IERC20(_tokenAddress);
        mainAirdropAmount = _initialMainAirdropAmount;
        referralBonusAmount = _initialReferralBonusAmount;
        claimFeePercent = _initialClaimFeePercent;
        totalAirdropSupply = _initialTotalAirdropSupply;
        merkleRoot = _initialMerkleRoot;
    }

    /**
     * @dev Fallback function to handle any accidental Ether sent to the contract.
     * It simply reverts the transaction, preventing the ETH from being locked.
     */
    receive() external payable {
        revert("ETH not accepted");
    }

    /**
     * @dev Modifier to ensure the airdrop is currently active.
     */
    modifier onlyActiveAirdrop() {
        require(isAirdropActive, "Airdrop is not active");
        _;
    }

    /**
     * @dev Allows the owner to start the airdrop.
     */
    function startAirdrop() public onlyOwner {
        require(!isAirdropActive, "Airdrop is already active");
        isAirdropActive = true;
        emit AirdropStarted();
    }

    /**
     * @dev Allows the owner to stop the airdrop.
     */
    function stopAirdrop() public onlyOwner {
        require(isAirdropActive, "Airdrop is already stopped");
        isAirdropActive = false;
        emit AirdropStopped();
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
     * @dev Allows the owner to set the Merkle root.
     * This is used to prove that a referrer is on the pre-approved whitelist.
     * @param _newRoot The new Merkle root.
     */
    function setMerkleRoot(bytes32 _newRoot) public onlyOwner {
        merkleRoot = _newRoot;
        emit MerkleRootUpdated(_newRoot);
    }

    /**
     * @dev A function for a user to claim their airdrop.
     * This function also handles the referral bonus and a configurable fee.
     * @param _referrer The address of the referrer. Use address(0) if there is no referrer.
     * @param _merkleProof The Merkle proof to prove the referrer is on the whitelist.
     */
    function claimAirdrop(address _referrer, bytes32[] calldata _merkleProof) public onlyActiveAirdrop nonReentrant {
        // Checks
        require(!claimed[msg.sender], "You have already claimed your airdrop");
        
        // Effects
        claimed[msg.sender] = true;

        // Interactions
        uint256 feeAmount = Math.mulDiv(mainAirdropAmount, claimFeePercent, 100);
        uint256 finalAirdropAmount = mainAirdropAmount - feeAmount;

        uint256 tokensToDistribute = finalAirdropAmount;

        // Handle referral bonus only if a valid referrer is provided and verified via Merkle proof.
        if (_referrer != address(0)) {
            require(_referrer != msg.sender, "Cannot self-refer");
            require(_referrer != address(this), "Invalid referrer");
            
            // Generate the leaf node for the Merkle proof.
            bytes32 leaf = keccak256(abi.encodePacked(_referrer));
            
            // Verify that the referrer's address is on the pre-approved whitelist.
            require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), "Invalid Merkle proof");

            tokensToDistribute += referralBonusAmount;
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
