// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DANPresaleMultiPay is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    IERC20 public immutable saleToken; // DAN token (assumed decimals 18)
    uint8 public immutable saleTokenDecimals = 18; // change if your token uses different decimals

    struct Phase {
        uint256 tokensAvailable; // in smallest units (saleTokenDecimals)
        uint256 tokensSold;      // in smallest units
        bool active;
    }

    Phase[] public phases;

    // per-phase native coin price (wei per 1 sale token (1 * 10**saleTokenDecimals))
    mapping(uint256 => uint256) public nativePricePerPhase;

    // per-phase per-ERC20 token price: price[phaseId][paymentToken] = paymentTokenUnits per 1 sale token
    // Example: for USDT (6 decimals), if price = 2 USDT per DAN token -> price = 2 * 10**6
    mapping(uint256 => mapping(address => uint256)) public erc20PricePerPhase;

    // accepted ERC20 payment tokens (owner can toggle)
    mapping(address => bool) public acceptedPaymentToken;

    // sale state
    bool public finalized;
    uint256 public totalSold; // in sale token smallest units
    uint256 public claimDeadline; // timestamp

    // buy controls
    uint256 public perTxNativeMaxWei = type(uint256).max;
    mapping(address => uint256) public perAddressCap; // cap in sale token smallest units (0 = no cap)

    // optional whitelist
    bool public whitelistOnly = false;
    mapping(address => bool) public whitelist;

    mapping(address => uint256) public purchased; // buyer => amount (smallest units)

    event PhaseAdded(uint256 indexed phaseId, uint256 tokensAvailable);
    event PhaseUpdated(uint256 indexed phaseId);
    event NativePriceSet(uint256 indexed phaseId, uint256 priceWei);
    event ERC20PriceSet(uint256 indexed phaseId, address indexed paymentToken, uint256 priceUnits);
    event PaymentTokenToggled(address indexed token, bool accepted);
    event BoughtNative(address indexed buyer, uint256 phaseId, uint256 weiSpent, uint256 tokensBought);
    event BoughtERC20(address indexed buyer, uint256 phaseId, address indexed paymentToken, uint256 paidAmount, uint256 tokensBought);
    event Claimed(address indexed who, uint256 amount);
    event Finalized(uint256 totalSold, uint256 claimDeadline);
    event WithdrawNative(address indexed to, uint256 amount);
    event WithdrawRemainingTokens(address indexed to, uint256 amount);
    event RecoveredERC20(address indexed token, address indexed to, uint256 amount);
    event WhitelistUpdated(address indexed who, bool allowed);
    event PerAddressCapSet(address indexed who, uint256 cap);
    event PerTxNativeMaxSet(uint256 maxWei);

    modifier onlyWhileNotFinalized() {
        require(!finalized, "presale finalized");
        _;
    }

    constructor(IERC20 _saleToken) Ownable(msg.sender) {
        require(address(_saleToken) != address(0), "zero sale token");
        saleToken = _saleToken;
    }

    // --------------------
    // Phase management
    // --------------------
    function addPhase(uint256 tokensAvailable, bool active) external onlyOwner onlyWhileNotFinalized whenNotPaused {
        require(tokensAvailable > 0, "tokensAvailable>0");
        phases.push(Phase({ tokensAvailable: tokensAvailable, tokensSold: 0, active: active }));
        emit PhaseAdded(phases.length - 1, tokensAvailable);
    }

    function updatePhase(uint256 phaseId, uint256 tokensAvailable, bool active) external onlyOwner onlyWhileNotFinalized whenNotPaused {
        require(phaseId < phases.length, "bad phase");
        Phase storage p = phases[phaseId];
        require(tokensAvailable >= p.tokensSold, "tokensAvailable < sold");
        p.tokensAvailable = tokensAvailable;
        p.active = active;
        emit PhaseUpdated(phaseId);
    }

    // set native price (wei per 1 sale token)
    function setNativePrice(uint256 phaseId, uint256 priceWei) external onlyOwner {
        require(phaseId < phases.length, "bad phase");
        require(priceWei > 0, "price>0");
        nativePricePerPhase[phaseId] = priceWei;
        emit NativePriceSet(phaseId, priceWei);
    }

    // set ERC20 price: payment token units per 1 sale token
    function setERC20Price(uint256 phaseId, address paymentToken, uint256 priceUnits) external onlyOwner {
        require(phaseId < phases.length, "bad phase");
        require(paymentToken != address(0), "zero token");
        require(priceUnits > 0, "price>0");
        erc20PricePerPhase[phaseId][paymentToken] = priceUnits;
        acceptedPaymentToken[paymentToken] = true;
        emit ERC20PriceSet(phaseId, paymentToken, priceUnits);
        emit PaymentTokenToggled(paymentToken, true);
    }

    function togglePaymentToken(address tokenAddr, bool accepted) external onlyOwner {
        acceptedPaymentToken[tokenAddr] = accepted;
        emit PaymentTokenToggled(tokenAddr, accepted);
    }

    // --------------------
    // Whitelist & caps
    // --------------------
    function setWhitelistOnly(bool enabled) external onlyOwner { whitelistOnly = enabled; }
    function setWhitelist(address who, bool allowed) external onlyOwner { whitelist[who] = allowed; emit WhitelistUpdated(who, allowed); }
    function batchSetWhitelist(address[] calldata addrs, bool allowed) external onlyOwner {
        for (uint i = 0; i < addrs.length; i++) { whitelist[addrs[i]] = allowed; emit WhitelistUpdated(addrs[i], allowed); }
    }

    function setPerAddressCap(address who, uint256 capTokens) external onlyOwner { perAddressCap[who] = capTokens; emit PerAddressCapSet(who, capTokens); }
    function setPerTxNativeMaxWei(uint256 maxWei) external onlyOwner { perTxNativeMaxWei = maxWei; emit PerTxNativeMaxSet(maxWei); }

    // --------------------
    // Buying (native coin)
    // --------------------
    // Buyer purchases tokens from a specific phase using native coin.
    // minTokens is buyer-provided slippage protection (in sale token smallest units)
    function buyWithNative(uint256 phaseId, uint256 minTokens) external payable nonReentrant whenNotPaused onlyWhileNotFinalized {
        require(msg.value > 0, "zero value");
        require(msg.value <= perTxNativeMaxWei, "exceeds per-tx max");
        if (whitelistOnly) require(whitelist[msg.sender], "not whitelisted");
        require(phaseId < phases.length, "invalid phase");
        Phase storage p = phases[phaseId];
        require(p.active, "phase inactive");
        uint256 priceWei = nativePricePerPhase[phaseId];
        require(priceWei > 0, "native price not set");

        // tokens = msg.value * (10**saleTokenDecimals) / priceWei
        uint256 tokensPossible = (msg.value * (10 ** saleTokenDecimals)) / priceWei;
        require(tokensPossible > 0, "insufficient funds for 1 token unit");

        uint256 allocLeft = p.tokensAvailable - p.tokensSold;
        uint256 tokensToBuy = tokensPossible;
        if (tokensToBuy > allocLeft) tokensToBuy = allocLeft;

        require(tokensToBuy >= minTokens, "slippage: less than minTokens");

        uint256 costWei = (tokensToBuy * priceWei) / (10 ** saleTokenDecimals);
        // rounding guard
        if (costWei > msg.value) costWei = msg.value;

        // update state
        p.tokensSold += tokensToBuy;
        purchased[msg.sender] += tokensToBuy;
        totalSold += tokensToBuy;

        // refund leftover native coin
        uint256 refundWei = msg.value - costWei;
        if (refundWei > 0) {
            (bool sent, ) = payable(msg.sender).call{value: refundWei}('');
            require(sent, "refund failed");
        }

        emit BoughtNative(msg.sender, phaseId, costWei, tokensToBuy);
    }

    // --------------------
    // Buying (ERC20 payment tokens, e.g., USDT)
    // --------------------
    // Buyer must approve `paymentAmount` for this contract prior to calling.
    // paymentAmount is the amount buyer wants to spend (in payment token smallest units).
    // minTokens is slippage protection (sale token smallest units).
    function buyWithERC20(uint256 phaseId, address paymentToken, uint256 paymentAmount, uint256 minTokens) external nonReentrant whenNotPaused onlyWhileNotFinalized {
        require(paymentAmount > 0, "zero payment");
        if (whitelistOnly) require(whitelist[msg.sender], "not whitelisted");
        require(acceptedPaymentToken[paymentToken], "token not accepted");
        require(phaseId < phases.length, "invalid phase");
        Phase storage p = phases[phaseId];
        require(p.active, "phase inactive");

        uint256 priceUnits = erc20PricePerPhase[phaseId][paymentToken];
        require(priceUnits > 0, "erc20 price not set for phase");

        IERC20 payToken = IERC20(paymentToken);

        // pull paymentAmount from buyer
        payToken.safeTransferFrom(msg.sender, address(this), paymentAmount);

        // Calculate tokensPossible = paymentAmount * (10**saleTokenDecimals) / priceUnits
        uint256 tokensPossible = (paymentAmount * (10 ** saleTokenDecimals)) / priceUnits;
        require(tokensPossible > 0, "insufficient payment for 1 token unit");

        uint256 allocLeft = p.tokensAvailable - p.tokensSold;
        uint256 tokensToBuy = tokensPossible;
        if (tokensToBuy > allocLeft) tokensToBuy = allocLeft;

        require(tokensToBuy >= minTokens, "slippage: less than minTokens");

        // compute actual cost in payment token units: cost = tokensToBuy * priceUnits / (10**saleTokenDecimals)
        uint256 costInPaymentUnits = (tokensToBuy * priceUnits) / (10 ** saleTokenDecimals);
        if (costInPaymentUnits > paymentAmount) costInPaymentUnits = paymentAmount; // rounding guard

        // refund leftover payment tokens if any
        uint256 refund = paymentAmount - costInPaymentUnits;
        if (refund > 0) {
            payToken.safeTransfer(msg.sender, refund);
        }

        // update state
        p.tokensSold += tokensToBuy;
        purchased[msg.sender] += tokensToBuy;
        totalSold += tokensToBuy;

        emit BoughtERC20(msg.sender, phaseId, paymentToken, costInPaymentUnits, tokensToBuy);
    }

    // --------------------
    // Claiming & Finalization
    // --------------------
    function finalizePresale(uint256 claimPeriodSeconds) external onlyOwner onlyWhileNotFinalized whenNotPaused {
        // require contract holds enough sale tokens to cover current sold state
        require(saleToken.balanceOf(address(this)) >= totalSold, "insufficient sale tokens deposited");

        finalized = true;

        if (claimPeriodSeconds == 0) {
            // default 30 days
            claimDeadline = block.timestamp + 30 days;
        } else {
            claimDeadline = block.timestamp + claimPeriodSeconds;
        }

        // deactivate all phases
        for (uint256 i = 0; i < phases.length; i++) {
            phases[i].active = false;
        }

        emit Finalized(totalSold, claimDeadline);
    }

    function claimTokens() external nonReentrant whenNotPaused {
        require(finalized, "not finalized");
        require(block.timestamp <= claimDeadline, "claim period over");
        uint256 amount = purchased[msg.sender];
        require(amount > 0, "nothing to claim");
        purchased[msg.sender] = 0;
        saleToken.safeTransfer(msg.sender, amount);
        emit Claimed(msg.sender, amount);
    }

    // Owner sweeps remaining sale tokens after claim deadline
    function sweepRemainingTokens(address to) external onlyOwner {
        require(finalized, "not finalized");
        require(block.timestamp > claimDeadline, "claim period not over");
        require(to != address(0), "zero addr");
        uint256 bal = saleToken.balanceOf(address(this));
        require(bal > 0, "no tokens");
        saleToken.safeTransfer(to, bal);
        emit WithdrawRemainingTokens(to, bal);
    }

    // Owner withdraw native funds (only after finalize)
    function withdrawNative(address payable to, uint256 amountWei) external onlyOwner {
        require(finalized, "withdraw allowed only after finalize");
        require(to != address(0), "zero addr");
        require(amountWei <= address(this).balance, "not enough balance");
        (bool sent, ) = to.call{value: amountWei}('');
        require(sent, "withdraw failed");
        emit WithdrawNative(to, amountWei);
    }

    // Owner recovers accidental ERC20 tokens (except sale token)
    function recoverERC20(address erc20, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "zero addr");
        require(erc20 != address(saleToken), "cannot recover sale token");
        IERC20(erc20).safeTransfer(to, amount);
        emit RecoveredERC20(erc20, to, amount);
    }

    // Pause/unpause
    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    // View helpers
    function phasesCount() external view returns (uint256) { return phases.length; }
    function phaseInfo(uint256 phaseId) external view returns (uint256 tokensAvailable, uint256 tokensSold, bool active, uint256 nativePrice) {
        require(phaseId < phases.length, "bad phase");
        Phase memory p = phases[phaseId];
        return (p.tokensAvailable, p.tokensSold, p.active, nativePricePerPhase[phaseId]);
    }

    // Prevent direct native transfers — require using buyWithNative()
    receive() external payable {
        revert("use buyWithNative()");
    }

    fallback() external payable {
        revert("use buyWithNative()");
    }
}
