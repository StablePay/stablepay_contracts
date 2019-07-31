pragma solidity 0.5.3;
pragma experimental ABIEncoderV2;


import "../../providers/ISwappingProvider.sol";

contract CustomSwappingProviderMock is ISwappingProvider {

    /** Properties */
    bool public _swapResult = true;
    uint256 public _minRate;
    uint256 public _maxRate;
    bool public _isSupported = true;

    /** Events */

    /** Modifiers */

    /** Constructor */

    constructor(address stablePay)
    public ISwappingProvider(stablePay) {}

    /** Methods */

    function setExpectedRate(bool isSupported, uint256 minRate, uint256 maxRate)
    public {
        _minRate = minRate;
        _maxRate = maxRate;
        _isSupported = isSupported;
    }

    function swapToken(StablePayCommon.Order memory order)
    public
    returns (bool) {
        order;
        return _swapResult;
    }

    function swapEther(StablePayCommon.Order memory order)
    public
    payable
    returns (bool) {
        order;
        return _swapResult;
    }

    function getExpectedRate(ERC20 src, ERC20 dest, uint srcQty)
    public
    view
    returns (bool isSupported, uint minRate, uint maxRate) {
        src; dest; srcQty;
        return (_isSupported, _minRate, _maxRate);
    }

    function deposit()
    public
    payable
    returns (bool)
    {
        return true;
    }

    function stablePayNonPayable()
    internal
    view
    returns (address payable) {
        return address(uint160(stablePay));
    }

    function _transferDiffEtherBalanceIfApplicable(address payable to, uint transferAmount)
    public
    payable
    returns (bool)
    {
        uint256 initialBalance = getEtherBalance();
        stablePayNonPayable().transfer(transferAmount);
        uint256 finalBalance = getEtherBalance();
        return super.transferDiffEtherBalanceIfApplicable(to, msg.value, initialBalance, finalBalance);
    }

    function _calculateDiffBalance(uint sentAmount, uint initialBalance, uint finalBalance)
    public
    pure
    returns (uint)
    {
        return super.calculateDiffBalance(sentAmount, initialBalance, finalBalance);
    }

    
}