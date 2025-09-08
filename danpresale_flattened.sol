
// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: @openzeppelin/contracts/security/ReentrancyGuard.sol


// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

// File: @openzeppelin/contracts/security/Pausable.sol


// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;


/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol


// OpenZeppelin Contracts (last updated v5.4.0) (token/ERC20/IERC20.sol)

pragma solidity >=0.4.16;

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// File: @openzeppelin/contracts/interfaces/IERC20.sol


// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC20.sol)

pragma solidity >=0.4.16;


// File: @openzeppelin/contracts/utils/introspection/IERC165.sol


// OpenZeppelin Contracts (last updated v5.4.0) (utils/introspection/IERC165.sol)

pragma solidity >=0.4.16;

/**
 * @dev Interface of the ERC-165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[ERC].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[ERC section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// File: @openzeppelin/contracts/interfaces/IERC165.sol


// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC165.sol)

pragma solidity >=0.4.16;


// File: @openzeppelin/contracts/interfaces/IERC1363.sol


// OpenZeppelin Contracts (last updated v5.4.0) (interfaces/IERC1363.sol)

pragma solidity >=0.6.2;



/**
 * @title IERC1363
 * @dev Interface of the ERC-1363 standard as defined in the https://eips.ethereum.org/EIPS/eip-1363[ERC-1363].
 *
 * Defines an extension interface for ERC-20 tokens that supports executing code on a recipient contract
 * after `transfer` or `transferFrom`, or code on a spender contract after `approve`, in a single transaction.
 */
interface IERC1363 is IERC20, IERC165 {
    /*
     * Note: the ERC-165 identifier for this interface is 0xb0202a11.
     * 0xb0202a11 ===
     *   bytes4(keccak256('transferAndCall(address,uint256)')) ^
     *   bytes4(keccak256('transferAndCall(address,uint256,bytes)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256)')) ^
     *   bytes4(keccak256('transferFromAndCall(address,address,uint256,bytes)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256)')) ^
     *   bytes4(keccak256('approveAndCall(address,uint256,bytes)'))
     */

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferAndCall(address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the allowance mechanism
     * and then calls {IERC1363Receiver-onTransferReceived} on `to`.
     * @param from The address which you want to send tokens from.
     * @param to The address which you want to transfer to.
     * @param value The amount of tokens to be transferred.
     * @param data Additional data with no specified format, sent in call to `to`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function transferFromAndCall(address from, address to, uint256 value, bytes calldata data) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value) external returns (bool);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens and then calls {IERC1363Spender-onApprovalReceived} on `spender`.
     * @param spender The address which will spend the funds.
     * @param value The amount of tokens to be spent.
     * @param data Additional data with no specified format, sent in call to `spender`.
     * @return A boolean value indicating whether the operation succeeded unless throwing.
     */
    function approveAndCall(address spender, uint256 value, bytes calldata data) external returns (bool);
}

// File: @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol


// OpenZeppelin Contracts (last updated v5.3.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.20;



/**
 * @title SafeERC20
 * @dev Wrappers around ERC-20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    /**
     * @dev An operation with an ERC-20 token failed.
     */
    error SafeERC20FailedOperation(address token);

    /**
     * @dev Indicates a failed `decreaseAllowance` request.
     */
    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Variant of {safeTransfer} that returns a bool instead of reverting if the operation is not successful.
     */
    function trySafeTransfer(IERC20 token, address to, uint256 value) internal returns (bool) {
        return _callOptionalReturnBool(token, abi.encodeCall(token.transfer, (to, value)));
    }

    /**
     * @dev Variant of {safeTransferFrom} that returns a bool instead of reverting if the operation is not successful.
     */
    function trySafeTransferFrom(IERC20 token, address from, address to, uint256 value) internal returns (bool) {
        return _callOptionalReturnBool(token, abi.encodeCall(token.transferFrom, (from, to, value)));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        forceApprove(token, spender, oldAllowance + value);
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
     * value, non-reverting calls are assumed to be successful.
     *
     * IMPORTANT: If the token implements ERC-7674 (ERC-20 with temporary allowance), and if the "client"
     * smart contract uses ERC-7674 to set temporary allowances, then the "client" smart contract should avoid using
     * this function. Performing a {safeIncreaseAllowance} or {safeDecreaseAllowance} operation on a token contract
     * that has a non-zero temporary allowance (for that particular owner-spender) will result in unexpected behavior.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 requestedDecrease) internal {
        unchecked {
            uint256 currentAllowance = token.allowance(address(this), spender);
            if (currentAllowance < requestedDecrease) {
                revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
            }
            forceApprove(token, spender, currentAllowance - requestedDecrease);
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     *
     * NOTE: If the token implements ERC-7674, this function will not modify any temporary allowance. This function
     * only sets the "standard" allowance. Any temporary allowance will remain active, in addition to the value being
     * set here.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Performs an {ERC1363} transferAndCall, with a fallback to the simple {ERC20} transfer if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            safeTransfer(token, to, value);
        } else if (!token.transferAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} transferFromAndCall, with a fallback to the simple {ERC20} transferFrom if the target
     * has no code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * Reverts if the returned value is other than `true`.
     */
    function transferFromAndCallRelaxed(
        IERC1363 token,
        address from,
        address to,
        uint256 value,
        bytes memory data
    ) internal {
        if (to.code.length == 0) {
            safeTransferFrom(token, from, to, value);
        } else if (!token.transferFromAndCall(from, to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Performs an {ERC1363} approveAndCall, with a fallback to the simple {ERC20} approve if the target has no
     * code. This can be used to implement an {ERC721}-like safe transfer that rely on {ERC1363} checks when
     * targeting contracts.
     *
     * NOTE: When the recipient address (`to`) has no code (i.e. is an EOA), this function behaves as {forceApprove}.
     * Opposedly, when the recipient address (`to`) has code, this function only attempts to call {ERC1363-approveAndCall}
     * once without retrying, and relies on the returned value to be true.
     *
     * Reverts if the returned value is other than `true`.
     */
    function approveAndCallRelaxed(IERC1363 token, address to, uint256 value, bytes memory data) internal {
        if (to.code.length == 0) {
            forceApprove(token, to, value);
        } else if (!token.approveAndCall(to, value, data)) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturnBool} that reverts if call fails to meet the requirements.
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            let success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            // bubble errors
            if iszero(success) {
                let ptr := mload(0x40)
                returndatacopy(ptr, 0, returndatasize())
                revert(ptr, returndatasize())
            }
            returnSize := returndatasize()
            returnValue := mload(0)
        }

        if (returnSize == 0 ? address(token).code.length == 0 : returnValue != 1) {
            revert SafeERC20FailedOperation(address(token));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silently catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        bool success;
        uint256 returnSize;
        uint256 returnValue;
        assembly ("memory-safe") {
            success := call(gas(), token, 0, add(data, 0x20), mload(data), 0, 0x20)
            returnSize := returndatasize()
            returnValue := mload(0)
        }
        return success && (returnSize == 0 ? address(token).code.length > 0 : returnValue == 1);
    }
}

// File: danpresale.sol


pragma solidity ^0.8.20;

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
