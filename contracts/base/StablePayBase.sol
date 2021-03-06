pragma solidity 0.5.10;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../base/Base.sol";
import "../interface/ISettings.sol";
import "../interface/IProviderRegistry.sol";
import "../interface/IPostActionRegistry.sol";
import "../interface/IPostAction.sol";
import "../interface/IStablePay.sol";
import "../interface/ISwappingProvider.sol";
import "../util/Bytes32ArrayLib.sol";

/**
    @notice This is the entry point to interact with the StablePay platform.
    @dev It defines the functions to swap and transfer any token (ERC20) or Ether into any pre-configured token (ERC20).
    @dev As StablePay doesn't use its own liquidity to swap tokens/ether, StablePay supports swap any token if at least one registered swapping provider supports it.

    @author StablePay <hi@stablepay.io>
 */
contract StablePayBase is Base, IStablePay {
    using SafeMath for uint256;
    using Bytes32ArrayLib for bytes32[];

    /** Constants */
    /**
        @notice The platform fee is multiplied by 100 to avoid decimal losses. It means the platform fee value configured in the contract Settings is:
            - 0.5% is 0.5 * 100 = 50
            - 1% is 1 * 100 = 100
            - 2% is 2 * 100 = 200
        @notice This constant defines the result of: platform fee value basis * percentage = 100 * 100
        @dev It is used in the 'getFeeAmount' function to divided the target amount by this value.
     */
    uint256 internal constant FEE_VALUE_BASIS_PERCENTAGE = 10000; // 100 * 100

    string internal constant STABLE_PAY_PROVIDER_REGISTRY_NAME = "StablePayStorage";
    string internal constant POST_ACTION_REGISTRY_NAME = "PostActionRegistry";

    /** Properties */

    /** Events */

    /** Modifiers */

    modifier isSender(address target) {
        require(msg.sender == target, "Sender is not equals to 'target' address.");
        _;
    }

    modifier isTokenAvailable(address tokenAddress, uint256 amount) {
        bool isAvailable = getSettings().isTokenAvailable(tokenAddress, amount);
        require(isAvailable, "Token amount is not available (gt or lt).");
        _;
    }

    modifier isPostActionValid(address postAction) {
        bool isPostAction = getPostActionRegistry().isRegisteredPostAction(postAction);
        require(postAction == address(0x0) || isPostAction, "Post action is not valid.");
        _;
    }

    modifier areOrderAmountsValidToken(StablePayCommon.Order memory order) {
        require(order.sourceAmount > 0, "Source amount is not gt 0.");
        require(order.targetAmount > 0, "Target amount is not gt 0.");
        _;
    }

    modifier areOrderAmountsValidEther(StablePayCommon.Order memory order) {
        require(msg.value > 0, "Msg value is not gt 0");
        require(order.sourceAmount > 0, "Source amount is not gt 0");
        require(msg.value == order.sourceAmount, "Msg value is not eq source amount");
        require(order.targetAmount > 0, "Target amount is not gt 0.");
        _;
    }

    /** Constructor */

    constructor(address storageAddress) public Base(storageAddress) {}

    /** Fallback Method */

    /** Functions */

    /**
        @dev Get the current Settings smart contract configured in the platform.
     */
    function getSettings() internal view returns (ISettings) {
        address settingsAddress = _storage.getAddress(
            keccak256(abi.encodePacked(CONTRACT_NAME, SETTINGS_NAME))
        );
        return ISettings(settingsAddress);
    }

    /**
        @dev Get the current ProviderRegistry smart contract configured in the platform.
     */
    function getProviderRegistry() internal view returns (IProviderRegistry) {
        address stablePayStorageAddress = _storage.getAddress(
            keccak256(abi.encodePacked(CONTRACT_NAME, STABLE_PAY_PROVIDER_REGISTRY_NAME))
        );
        return IProviderRegistry(stablePayStorageAddress);
    }

    function getPostActionRegistry() internal view returns (IPostActionRegistry) {
        address postActionRegistryAddress = _storage.getAddress(
            keccak256(abi.encodePacked(CONTRACT_NAME, POST_ACTION_REGISTRY_NAME))
        );
        return IPostActionRegistry(postActionRegistryAddress);
    }

    /**
        @dev Get the swapping provider struct for a given provider key.
     */
    function getSwappingProvider(bytes32 providerKey)
        public
        view
        returns (StablePayCommon.SwappingProvider memory)
    {
        return getProviderRegistry().getSwappingProvider(providerKey);
    }

    /**
        @dev Calculates the fee amount based on the target amount and the pre configured platform fee value.

        @param order order instance which defines the data needed to make the swap (ether to token) and transfer.
        @return the fee amount for the target amount in the order.
     */
    function getFeeAmount(StablePayCommon.Order memory order)
        internal
        view
        returns (uint256)
    {
        // Gets the platform fee multiplied by 100.
        uint256 platformFee = uint256(getSettings().getPlatformFee());

        // Calculating the fee amount using the formula:
        //      target amount * platform fee / (100 -fee value basis- * 100 -Percentage-)
        uint256 feeAmountAvoidDecimals = order.targetAmount.mul(platformFee).div(
            FEE_VALUE_BASIS_PERCENTAGE
        );

        return feeAmountAvoidDecimals;
    }

    /**
        @dev It transfers a specific amount of tokens as a fee to the platform Vault smart contract.
        @dev It throws a require error if the transfer result is not success. 
        @dev Otherwise it returns true.
     */
    function transferFee(address _tokenAddress, uint256 _feeAmount) internal {
        if (_feeAmount > 0) {
            bool result = IERC20(_tokenAddress).transfer(getVault(), _feeAmount);
            require(result, "Tokens transfer to vault was invalid.");
        }
    }

    /** 
        @dev Verify the given allowance to a spender against a specific amount.
        @dev It throws a require error if the allowance is not higher (or equals) than the specific amount.
        @dev Otherwise it returns true.
     */
    function allowanceHigherOrEquals(
        address token,
        address owner,
        address spender,
        uint256 amount
    ) internal view {
        uint256 allowanceResult = IERC20(token).allowance(owner, spender);
        require(allowanceResult >= amount, "Not enough allowed tokens to StablePay.");
    }

    /**
        @dev It transfers an amount of tokens to a specific address.
        @dev It throws a require error, if the transfer from result is false.
        @dev Otherwise it returns true.
     */
    function transferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        if (amount > 0) {
            bool transferFromResult = IERC20(token).transferFrom(from, to, amount);
            require(transferFromResult, "Transfer from StablePay was not successful.");
        }
    }

    /**
        @dev It gets the current balance for this smart contract for a specific token (ERC20).
        @dev It returns the balance. 
     */
    function getTokenBalanceOf(address token) internal view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /**
        @dev It gets the current ether balance for this smart contract.
        @dev It returns the current balance.
     */
    function getEtherBalanceOf() internal view returns (uint256) {
        return address(this).balance;
    }

    /**
        @dev It transfers tokens (diff between final - initial balance) to a specific address when diff is higher than zero.
        @dev If final balance is lower than initial balance, it throws a require error.
     */
    function transferDiffSourceTokensIfApplicable(
        address token,
        address to,
        uint256 initialBalance,
        uint256 finalBalance
    ) internal returns (bool, uint256) {
        require(
            finalBalance >= initialBalance,
            "StablePayBase Token: Final balance is not gte initial balance."
        );
        uint256 tokensDiff = finalBalance.sub(initialBalance);
        if (tokensDiff > 0) {
            bool transferResult = IERC20(token).transfer(to, tokensDiff);
            require(transferResult, "Transfer tokens back failed.");
        }
        return (true, tokensDiff);
    }

    function calculateDiffBalance(
        uint256 sentAmount,
        uint256 initialBalance,
        uint256 finalBalance
    ) internal pure returns (uint256 diffBalance) {
        require(
            initialBalance >= finalBalance,
            "SwappingProvider Ether: Initial balance is not gte final balance."
        );
        uint256 used = initialBalance.sub(finalBalance);
        require(
            sentAmount >= used,
            "SwappingProvider Ether: Sent amount is not gte used amount."
        );
        return sentAmount.sub(used);
    }

    /**
        @dev It transfers back to an address the diff balances.
        @dev It assumes that the contract may already have balance.
        @dev Based on that, this function get the diff balance between what the sender sent and paid. The diff is transfer back to the sender.
        @dev Remember: After the swapping the final balance is lower than initial balance.
     */
    function transferDiffEtherBalanceIfApplicable(
        address payable to,
        uint256 sentAmount,
        uint256 initialBalance,
        uint256 finalBalance
    ) internal returns (bool, uint256) {
        uint256 diffAmount = calculateDiffBalance(
            sentAmount,
            initialBalance,
            finalBalance
        );
        if (diffAmount > 0) {
            to.transfer(diffAmount);
        }
        return (true, diffAmount);
    }

    /**
        @dev It checks whether the diff between final and initial balance is equals to a target amount.
        @dev If diff balance is not equals to target amount, it throws a require error.
     */
    function checkCurrentTargetBalance(
        uint256 targetAmount,
        uint256 initialBalance,
        uint256 finalBalance
    ) internal pure {
        require(
            finalBalance >= initialBalance,
            "StablePayBase: Final balance must be gte initial balance."
        );
        uint256 currentBalance = finalBalance.sub(initialBalance);
        require(
            currentBalance == targetAmount,
            "Target final tokens balance is not valid."
        );
    }

    /**
        @dev Calculate the platform fee amount based on the order target amount and platform fee.
        @dev Transfer the calculated fee amount. 
     */
    function calculateAndTransferFee(StablePayCommon.Order memory order)
        internal
        returns (uint256 feeAmount)
    {
        // Calculate the fee amount based on the target amount and the platform fee.
        uint256 currentFeeAmount = getFeeAmount(order);
        // Transfer the fee amount
        transferFee(order.targetToken, currentFeeAmount);
        return currentFeeAmount;
    }

    /**
        @notice Calculate the 'target' amount based on the order target amount and platform fee amount.
        @notice Transfer the 'target' amount to the post action address defined in order or pre-configured as default post action.

        @return the process was done, and the amount transfered to the 'target' account.
     */
    function calculateAndTransferAmountToPostActionAddress(
        StablePayCommon.Order memory order,
        uint256 feeAmount
    ) internal returns (uint256 toAmount) {
        address postActionAddress = getPostActionRegistry().getPostActionOrDefault(
            order.postActionAddress
        );

        // Calculate the 'target' amount.
        uint256 currentToAmount = order.targetAmount.sub(feeAmount);

        // Transfer the 'target' amount to the post action.
        bool transferToPostActionResult = IERC20(order.targetToken).transfer(
            postActionAddress,
            currentToAmount
        );
        require(transferToPostActionResult, "Transfer to 'target' address failed.");

        StablePayCommon.PostActionData memory postActionData = createPostActionData(
            order,
            currentToAmount,
            feeAmount
        );

        // Execute the post-action.
        IPostAction postAction = IPostAction(postActionAddress);
        postAction.execute(postActionData);

        return currentToAmount;
    }

    /**
        @notice It creates a PostActionData struct instance based on the sent order and calculated fee amount.

        @param order order instance which defines the data needed to make the swap (ether to token) and transfer.
        @param feeAmount amount calculated for this swapping. See 'getFeeAmount' function.
        @return a new PostActionData struct instance.
     */
    function createPostActionData(
        StablePayCommon.Order memory order,
        uint256 toAmount,
        uint256 feeAmount
    ) internal pure returns (StablePayCommon.PostActionData memory) {
        return
            StablePayCommon.PostActionData({
                sourceAmount: order.sourceAmount,
                targetAmount: order.targetAmount,
                toAmount: toAmount,
                minRate: order.minRate,
                maxRate: order.maxRate,
                feeAmount: feeAmount,
                sourceToken: order.sourceToken,
                targetToken: order.targetToken,
                toAddress: order.toAddress,
                fromAddress: order.fromAddress,
                data: order.data
            });
    }

    /**
        @notice Transfer tokens to the 'target' address if source and target tokens are equal.
        @param order order instance which defines the data needed to make the swap (ether to token) and transfer.
        @return true if source and target token addresses are equal. Otherwise it returns false.
      */
    function transferTokensIfTokensAreEquals(StablePayCommon.Order memory order)
        internal
        returns (bool)
    {
        // Verify if token addresses are equal.
        bool _isTransferTokens = order.sourceToken == order.targetToken;
        if (_isTransferTokens) {
            // Source / Target tokens are equal.
            // Check tokens allowance.
            uint256 allowanceResult = IERC20(order.sourceToken).allowance(
                msg.sender,
                address(this)
            );
            require(
                allowanceResult >= order.targetAmount,
                "Not enough allowed tokens to StablePay."
            );

            // Transfer tokens to the 'target' address without paying platform fees.
            bool transferFromResult = IERC20(order.sourceToken).transferFrom(
                msg.sender,
                order.toAddress,
                order.targetAmount
            );
            require(transferFromResult, "Transfer from StablePay was not successful.");

            // Emit PaymentSent event for the from/to order.
            emitPaymentSentEvent(order, order.targetAmount);

            // Emit ExecutionTransferSuccess event for StablePay.
            emitExecutionTransferSuccessEvent(
                order,
                uint256(0),
                order.targetAmount,
                0,
                0x0
            );
        }
        return _isTransferTokens;
    }

    /**
        @notice It does the transfer/swap between tokens using a swapping provider.
        @dev After swapping, it checks whether the target amount is equal to the current balance (of this contract). If it is not equals, it throws a require error. See 'checkCurrentTargetBalance' function.

        @param order order instance which defines the data needed to make the swap (ether to token) and transfer.
        @param providerKey associated to a specific swapping provider which will be used to attempt to make the ether/token swapping.
        @return true if the swapping was done. Otherwise it returns false.
     */
    function doTransferWithTokens(StablePayCommon.Order memory order, bytes32 providerKey)
        internal
        returns (bool)
    {
        // Check tokens allowance to StablePayBase smart contract.
        allowanceHigherOrEquals(
            order.sourceToken,
            msg.sender,
            address(this),
            order.sourceAmount
        );

        // Get the swapping provider (struct) for the given provider key.
        StablePayCommon.SwappingProvider memory swappingProvider = getSwappingProvider(
            providerKey
        );

        // Transfer tokens from the msg.sender (token owner) to swapping provider.
        // The owner already allowed to StablePay (this contract) transfer the tokens.
        transferFrom(
            order.sourceToken,
            msg.sender,
            swappingProvider.providerAddress,
            order.sourceAmount
        );

        // Get the current source/target token balances for StablePay.
        uint256 stablePaySourceInitialBalance = getTokenBalanceOf(order.sourceToken);
        uint256 stablePayTargetInitialBalance = getTokenBalanceOf(order.targetToken);

        // Get the swapping provider (smart contract) to make the swapping.
        ISwappingProvider iSwappingProvider = ISwappingProvider(
            swappingProvider.providerAddress
        );

        // Execute the swapping token using a given provider.
        if (iSwappingProvider.swapToken(order)) {
            // Get source token balance for StablePay.
            uint256 stablePaySourceFinalBalance = getTokenBalanceOf(order.sourceToken);

            // Transfer the difference between initial/final tokens to the 'target' address when the diff > 0.
            // The final balance is higher than initial
            uint256 tokensDiff;
            (, tokensDiff) = transferDiffSourceTokensIfApplicable(
                order.sourceToken,
                msg.sender,
                stablePaySourceInitialBalance,
                stablePaySourceFinalBalance
            );

            // Get target token balance for StablePay
            uint256 stablePayTargetFinalBalance = getTokenBalanceOf(order.targetToken);

            // Check current StablePay target token balance. It must be equals to order target amount.
            checkCurrentTargetBalance(
                order.targetAmount,
                stablePayTargetInitialBalance,
                stablePayTargetFinalBalance
            );

            // Calculate and transfer the platform fee amount.
            uint256 feeAmount = calculateAndTransferFee(order);

            // Calculate and transfer the 'target' amount.
            uint256 toAmount = calculateAndTransferAmountToPostActionAddress(
                order,
                feeAmount
            );

            // Emit PaymentSent event for the from/to order.
            emitPaymentSentEvent(order, toAmount);

            // Emit ExecutionTransferSuccess event for StablePay.
            emitExecutionTransferSuccessEvent(
                order,
                feeAmount,
                toAmount,
                tokensDiff,
                providerKey
            );

            return true;
        }

        // Emit ExecutionTransferFailed event for StablePay.
        emitExecutionTransferFailedEvent(
            order,
            swappingProvider.providerAddress,
            providerKey
        );
        return false;
    }

    /**
        @notice It checks the order struct values, and provider keys.
        @dev If a value is not valid, it throws a require error.

        @param order order instance which defines the data needed to make the transfer and swap if needed.
     */
    function requireTransferWithTokens(StablePayCommon.Order memory order)
        internal
        view
        isNotPaused()
        isPostActionValid(order.postActionAddress)
        isTokenAvailable(order.targetToken, order.targetAmount)
        areOrderAmountsValidToken(order)
        isSender(order.fromAddress)
    {}

    /**
        @notice It transfers (and swaps if needed) a specific amount of tokens (defined in the order) to a specific receiver.
        @dev If the source and target tokens are the same, StablePay only transfers the amount of tokens defined in the order.
        @dev Otherwise, StablePay uses each swapping provider ordered in the keys provided as input.
        @dev The provider keys list must be not empty in order to swap the tokens.

        @param order order instance which defines the data needed to make the transfer and swap if needed.
        @param providerKey provider key to be used as liquidity providers in the swapping process.
     */
    function transferWithTokens(StablePayCommon.Order memory order, bytes32 providerKey)
        public
    {
        requireTransferWithTokens(order);

        // Transfer tokens if source / target tokens are equal.
        if (transferTokensIfTokensAreEquals(order)) {
            return;
        }

        // Verify if the swapping provider is valid.
        if (getProviderRegistry().isSwappingProviderValid(providerKey)) {
            if (doTransferWithTokens(order, providerKey)) {
                return; // The swapping was ok.
            }
        }

        revert("Swapping token could not be processed.");
    }

    /**
        @notice It does the transfer/swap between ether and token using a swapping provider.
        @dev After swapping, it checks whether the target amount is equal to the current balance (of this contract). If it is not equals, it throws a require error. See 'checkCurrentTargetBalance' function.

        @param order order instance which defines the data needed to make the swap (ether to token) and transfer.
        @param providerKey associated to a specific swapping provider which will be used to attempt to make the ether/token swapping.
        @return true if the swapping was done. Otherwise it returns false.
     */
    function doTransferWithEthers(StablePayCommon.Order memory order, bytes32 providerKey)
        internal
        returns (bool)
    {
        // Get the swapping provider (struct) for the given provider key.
        StablePayCommon.SwappingProvider memory swappingProvider = getSwappingProvider(
            providerKey
        );

        // Get the initial source/target balances.
        uint256 stablePayInitialSourceBalance = getEtherBalanceOf();
        uint256 stablePayInitialTargetBalance = getTokenBalanceOf(order.targetToken);

        // Get the swapping provider (smart contract) to make the swapping.
        ISwappingProvider iSwappingProvider = ISwappingProvider(
            swappingProvider.providerAddress
        );

        // Execute the swapping process using a specific provider.
        if (iSwappingProvider.swapEther.value(msg.value)(order)) {
            // Get the final source/target balances.
            uint256 stablePayFinalSourceBalance = getEtherBalanceOf();
            uint256 stablePayFinalTargetBalance = getTokenBalanceOf(order.targetToken);

            // Transfer back the Ether left to the 'sender' address.
            uint256 diffEthers;
            (, diffEthers) = transferDiffEtherBalanceIfApplicable(
                msg.sender,
                msg.value,
                stablePayInitialSourceBalance,
                stablePayFinalSourceBalance
            );

            // Check current StablePay target token balance. It must be equals to order target amount.
            checkCurrentTargetBalance(
                order.targetAmount,
                stablePayInitialTargetBalance,
                stablePayFinalTargetBalance
            );

            // Calculate and transfer the platform fee amount.
            uint256 feeAmount = calculateAndTransferFee(order);

            // Calculate and transfer the 'target' amount.
            uint256 toAmount = calculateAndTransferAmountToPostActionAddress(
                order,
                feeAmount
            );

            // Emit PaymentSent event for the from/to order.
            emitPaymentSentEvent(order, toAmount);

            // Emit ExecutionTransferSuccess event for StablePay.
            emitExecutionTransferSuccessEvent(
                order,
                feeAmount,
                toAmount,
                diffEthers,
                providerKey
            );

            return true;
        }

        // Emit ExecutionTransferFailed event for StablePay.
        emitExecutionTransferFailedEvent(
            order,
            swappingProvider.providerAddress,
            providerKey
        );
        return false;
    }

    /**
        @notice It checks the order struct values, and provider keys.
        @dev If a value is not valid, it throws a require error.

        @param order order instance which defines the data needed to make the transfer and swap if needed.
     */
    function requireTransferWithEthers(StablePayCommon.Order memory order)
        internal
        view
        isNotPaused()
        isPostActionValid(order.postActionAddress)
        isTokenAvailable(order.targetToken, order.targetAmount)
        areOrderAmountsValidEther(order)
        isSender(order.fromAddress)
    {}

    /**
        @notice It swaps and transfers a specific amount of ether (defined in the order and msg.value parameter) to a specific amount of tokens and finally transfers it to a receiver address.
        @dev StablePay uses each swapping provider ordered in the keys provided as input to attempt the swapping/exchange ether/tokens.
        @dev The provider keys list must be not empty in order to swap the tokens.

        @param order order instance which defines the data needed to make the swap (ether to token) and transfer.
        @param providerKey provider key to be used as liquidity providers in the swapping process.
     */
    function transferWithEthers(StablePayCommon.Order memory order, bytes32 providerKey)
        public
        payable
    {
        requireTransferWithEthers(order);

        // Verify if the swapping provider is valid.
        if (getProviderRegistry().isSwappingProviderValid(providerKey)) {
            if (doTransferWithEthers(order, providerKey)) {
                return; // The swapping was ok.
            }
        }
        revert("Swap with ether could not be performed.");
    }

    function emitExecutionTransferFailedEvent(
        StablePayCommon.Order memory order,
        address providerAddress,
        bytes32 providerKey
    ) internal {
        emit ExecutionTransferFailed(
            address(this),
            providerAddress,
            order.sourceToken,
            order.targetToken,
            order.fromAddress,
            order.toAddress,
            now,
            providerKey,
            order.data
        );
    }

    function emitExecutionTransferSuccessEvent(
        StablePayCommon.Order memory order,
        uint256 feeAmount,
        uint256 toAmount,
        uint256 amountDiff,
        bytes32 providerKey
    ) internal {
        // Note: Provider address is not added due to a Stack too deep error. It can be taken from provider key.
        uint16 platformFee = order.sourceToken == order.targetToken
            ? 0
            : getSettings().getPlatformFee();
        emit ExecutionTransferSuccess(
            providerKey,
            order.sourceToken,
            order.targetToken,
            order.fromAddress,
            order.toAddress,
            order.sourceAmount.sub(amountDiff),
            toAmount,
            feeAmount,
            platformFee,
            order.data
        );
    }

    /**
        @notice It emits the PaymentSent event.
        @dev It should be called after swapping and transfering the target tokens to the receiver address.
        @param order order instance associated with the swapping/transferring process.
        @param amountSent amount of tokens sent to the receiver address.
     */
    function emitPaymentSentEvent(StablePayCommon.Order memory order, uint256 amountSent)
        internal
    {
        emit PaymentSent(
            address(this),
            order.toAddress,
            msg.sender,
            order.sourceToken,
            order.targetToken,
            amountSent
        );
    }
}
