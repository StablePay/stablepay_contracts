pragma solidity 0.5.3;

import "../base/Base.sol";
import "../util/SafeMath.sol";
import "../interface/IPostActionRegistry.sol";

/**
    @title This smart contract manages all the IPostAction smart contracts for the platform.
    @author StablePay <hi@stablepay.io>

    @dev Only owner or admin users can invoke some functions.
 */
contract PostActionRegistry is Base, IPostActionRegistry {
    using SafeMath for uint256;

    /** Constants */
    string internal constant PLATFORM_DEFAULT_POST_ACTION = "config.platform.defaultPostAction";

    /** Properties */

    /**
        @dev This mapping is used to store actions.
     */
    mapping(address => bool) public actions;

    /** Modifiers */

    /**
        @notice It checks whether a post action address is empty or not.
        @dev It throws a require error if post action is empty.
        @param postAction address to check.
     */
    modifier isValidAddress(address postAction) {
        require(postAction != address(0x0), "Post action must be != 0x0.");
        _;
    }

    /**
        @notice It checks whether a post action address exists or not.
        @dev It throws a require error if post action doesn't exist.
        @param postAction address to check.
     */
    modifier postActionExists(address postAction) {
        require(actions[postAction] == true, "Post action must exist.");
        _;
    }

    /**
        @notice It checks whether a post action address exists or not.
        @dev It throws a require error if post action exists.
        @param postAction address to check.
     */
    modifier postActionNotExists(address postAction) {
        require(actions[postAction] == false, "Post action must not exist.");
        _;
    }

    /** Constructor */

    /**
        @notice It creates a new PostActionRegistry instance associated to an Eternal Storage implementation.
        @param storageAddress the Eternal Storage implementation.
        @dev The Eternal Storage implementation must implement the IStorage interface.
     */
    constructor(address storageAddress) public Base(storageAddress) {}

    /** Fallback Method */

    /** Functions */

    /**
        @notice It registers a new post action in the platform.
        @dev The sender must be a super user.
        @dev The post action address must not be empty.
        @param newPostAction the post action address to register.
        @return true if the post action is registered. Otherwise it returns false.
     */
    function registerPostAction(address newPostAction)
        external
        onlySuperUser
        isValidAddress(newPostAction)
        postActionNotExists(newPostAction)
        returns (bool)
    {
        actions[newPostAction] = true;

        emit NewPostActionRegistered(
            address(this),
            newPostAction,
            msg.sender,
            now
        );

        return true;
    }

    /**
        @notice It unregisters a already registered post action in the platform.
        @dev The sender must be a super user.
        @param postAction the post action to unregister.
        @return true if the post action is unregistered. Otherwise it returns false.
     */
    function unregisterPostAction(address postAction)
        external
        onlySuperUser
        isValidAddress(postAction)
        postActionExists(postAction)
        returns (bool)
    {
        actions[postAction] = false;

        emit PostActionUnregistered(address(this), postAction, msg.sender, now);
        return true;
    }

    /**
        @notice It tests whether a post action address is already registered.
        @param postAction to test whether it is registered.
        @return true if post action is registered. Otherwise it returns false.
     */
    function isRegisteredPostAction(address postAction)
        external
        view
        returns (bool)
    {
        return isRegisteredPostActionInternal(postAction);
    }

    function isRegisteredPostActionInternal(address postAction)
        internal
        view
        returns (bool)
    {
        return actions[postAction];
    }

    /**
        @notice It gets the default post action.
        @return the default post action.
     */
    function getDefaultPostAction() external view returns (address) {
        return getDefaultPostActionInternal();
    }

    function getDefaultPostActionInternal() internal view returns (address) {
        return
            _storage.getAddress(
                keccak256(abi.encodePacked(PLATFORM_DEFAULT_POST_ACTION))
            );
    }

    /**
        @notice It gets the post action or the default post action if the post action passed a parameter is not valid (pre-registered).
        @param postAction post action to verify if it is registered.
        @return the post action passed as parameter if it is registered. Otherwise it returns the default post action.
     */
    function getPostActionOrDefault(address postAction)
        external
        view
        returns (address)
    {
        bool isRegistered = isRegisteredPostActionInternal(postAction);
        return isRegistered ? postAction : getDefaultPostActionInternal();
    }

    /**
        @notice It sets a post action as default in the platform.
        @param postAction post action address to set as default in the platform.
        @return true if the post action is set as default. Otherwise it returns false.
     */
    function setPostActionAsDefault(address postAction)
        external
        onlySuperUser
        isValidAddress(postAction)
        postActionExists(postAction)
        returns (bool)
    {
        address previousDefaultPostAction = getDefaultPostActionInternal();
        require(
            previousDefaultPostAction != postAction,
            "New default post action must be != from current."
        );

        _storage.setAddress(
            keccak256(abi.encodePacked(PLATFORM_DEFAULT_POST_ACTION)),
            postAction
        );

        emit NewDefaultPostAction(
            address(this),
            previousDefaultPostAction,
            postAction,
            msg.sender,
            now
        );
        return true;
    }
}