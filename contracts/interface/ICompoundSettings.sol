pragma solidity 0.5.3;

/**
    @notice This is an abstraction for the Compound.finance settings integration in the platform.
    @author StablePay <hi@stablepay.io>
 */
interface ICompoundSettings {
    /** Events */

    /**
        @notice This event is emitted when a new Erc20 <> CErc20 mapping is registered.
     */
    event Erc20ToCEr20MappingCreated (
        address indexed thisContract,
        address erc20Address,
        address cErc20Address
    );

    /**
        @notice This event is emitted when a current Erc20 <> CErc20 mapping is updated.
     */
    event Erc20ToCEr20MappingUpdated (
        address indexed thisContract,
        address oldCerc20Address,
        address erc20Address,
        address cErc20Address
    );

    /** Functions */

    /**
        @notice It maps a ERC20 token to a CErc20 token (Compound.finance platform implementation).
        @param erc20Address ERC20 implementation address.
        @param cErc20Address CErc20 implementation address
        @return true if it was mapped successfully. Otherwise, it returns false.
     */
    function mapErc20ToCEr20(address erc20Address, address cErc20Address) external returns (bool);

    /**
        @notice It updates the current CErc20 mapping for a ERC20.
        @param erc20Address ERC20 implementation address.
        @param newCErc20Address new CErc20 implementation address.
        @return true if it was mapped successfully. Otherwise, it returns false.
     */
    function updateMapErc20ToCEr20(address erc20Address, address newCErc20Address) external returns (bool);

    /**
        @notice It gets the current CErc20 mapping for a specific ERC20 address.
        @param erc20Address ERC20 address to get the mapping.
        @return the current CErc20 mapping for a specific ERC20 address.
     */
    function getCEr20(address erc20Address) external view returns (address);

    /**
        @notice It tests whether an ERC20 address is supported or not.
        @param erc20Address ERC20 address to test.
        @return true if ERC20 address has a CErc20 mapped. Otherwise, it returns false.
     */
    function supportErc20(address erc20Address) external view returns (bool);

}