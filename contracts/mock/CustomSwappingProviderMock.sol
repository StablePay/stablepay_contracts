pragma solidity 0.4.25;
pragma experimental ABIEncoderV2;


import "../providers/ISwappingProvider.sol";

/**

 */
contract CustomSwappingProviderMock is ISwappingProvider {

    /** Properties */
    bool public _swapResult = true;
    uint256 public _minRate;
    uint256 public _maxRate;
    bool public _isSupported = true;

    /** Events */

    /** Modifiers */

    /** Constructor */

    constructor(address _stablePay)
    public ISwappingProvider(_stablePay) {}

    /** Methods */

    function setExpectedRate(bool isSupported, uint256 minRate, uint256 maxRate)
    public {
        _minRate = minRate;
        _maxRate = maxRate;
        _isSupported = isSupported;
    }

    function swapToken(StablePayCommon.Order order)
    public
    returns (bool) {
        order;
        return _swapResult;
    }

    function swapEther(StablePayCommon.Order order)
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

}