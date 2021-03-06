// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.6.0;

import "../_LSPs/ILSP1_UniversalReceiver.sol";

import "./ERC777.sol";
import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";


/**
 * @dev Implementation of the `IERC777` interface. With the use of the LSP1UniversalReceiver.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using `_mint`.
 *
 * Support for ERC20 is included in this contract, as specified by the EIP: both
 * the ERC777 and ERC20 interfaces can be safely used when interacting with it.
 * Both `IERC777.Sent` and `IERC20.Transfer` events are emitted on token
 * movements.
 *
 * Additionally, the `granularity` value is hard-coded to `1`, meaning that there
 * are no special restrictions in the amount of tokens that created, moved, or
 * destroyed. This makes integration with ERC20 applications seamless.
 */
contract ERC777UniversalReceiver_1820 is ERC777 {

    IERC1820Registry private ERC1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

    bytes32 constant internal _TOKENS_SENDER_INTERFACE_HASH =
    0x29ddb589b1fb5fc7cf394961c1adf5f8c6454761adf795e67fe149f658abe895; // keccak256("ERC777TokensSender")

    bytes32 constant internal _TOKENS_RECIPIENT_INTERFACE_HASH =
    0xb281fc8c12954d22544db45de3159a39272895b169a852b314f9cc762e44c53b; // keccak256("ERC777TokensRecipient")

    /**
     * @dev `defaultOperators` may be an empty array.
     */
    constructor(
        string memory name,
        string memory symbol,
        address[] memory defaultOperators
    ) public {
        _name = name;
        _symbol = symbol;

        _defaultOperatorsArray = defaultOperators;
        for (uint256 i = 0; i < _defaultOperatorsArray.length; i++) {
            _defaultOperators[_defaultOperatorsArray[i]] = true;
        }

        // register interfaces
        _ERC1820_REGISTRY.setInterfaceImplementer(address(this), keccak256("ERC777Token"), address(this));
        _ERC1820_REGISTRY.setInterfaceImplementer(address(this), keccak256("ERC20Token"), address(this));
    }

    function mint(uint256 _amount) external {
        require(_defaultOperators[_msgSender()], 'Only default operators can mint');

        _mint(_msgSender(), _amount, "", "");
    }


    /**
     * @dev Call from.tokensToSend() if the interface is registered
     * @param operator address operator requesting the transfer
     * @param from address token holder address
     * @param to address recipient address
     * @param amount uint256 amount of tokens to transfer
     * @param userData bytes extra information provided by the token holder (if any)
     * @param operatorData bytes extra information provided by the operator (if any)
     */
    function _callTokensToSend(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    )
        internal
        override
    {
        address implementer = ERC1820.getInterfaceImplementer(from, _TOKENS_SENDER_INTERFACE_HASH);
        if (implementer != address(0)) {
            bytes memory data = abi.encodePacked(operator, from, to, amount, userData, operatorData);
            ILSP1(implementer).universalReceiver(_TOKENS_SENDER_INTERFACE_HASH, data);
        }
    }

    /**
     * @dev Call to.tokensReceived() if the interface is registered. Reverts if the recipient is a contract but
     * tokensReceived() was not registered for the recipient
     * @param operator address operator requesting the transfer
     * @param from address token holder address
     * @param to address recipient address
     * @param amount uint256 amount of tokens to transfer
     * @param userData bytes extra information provided by the token holder (if any)
     * @param operatorData bytes extra information provided by the operator (if any)
     * @param requireReceptionAck if true, contract recipients are required to implement ERC777TokensRecipient
     */
    function _callTokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData,
        bool requireReceptionAck
    )
        internal
        override
    {
        address implementer = ERC1820.getInterfaceImplementer(to, _TOKENS_RECIPIENT_INTERFACE_HASH);
        if (implementer != address(0)) {
            // Call universal receiver on receiving contract, send supported type: TOKENS_RECIPIENT_INTERFACE_HASH
            bytes memory data = abi.encodePacked(operator, from, to, amount, userData, operatorData);
            ILSP1(implementer).universalReceiver(_TOKENS_RECIPIENT_INTERFACE_HASH, data);
        } else if (requireReceptionAck) {
            require(!to.isContract(), "ERC777: token recipient contract has no universal receiver for 'ERC777TokensRecipient'");
        }
    }
}
