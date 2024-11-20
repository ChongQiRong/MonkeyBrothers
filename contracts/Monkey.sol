// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./ERC165/ERC165.sol";
import "../contracts/ERC721/IERC721.sol";
import "../contracts/ERC721/IERC721Metadata.sol";
import "../contracts/ERC721/IERC721Receiver.sol";
import "./Ownable.sol";

/**
 * @title Monkeys
 * @author MonkeyBrothers
 * @notice NFT implementation for Monkey Brothers game characters
 * @dev ERC721 token with additional gaming attributes and metadata
 */
contract Monkeys is ERC165, IERC721, IERC721Metadata, Ownable {
    /// @notice Name of the NFT collection
    string private _name;
    /// @notice Symbol of the NFT collection
    string private _symbol;
    /// @notice Base URI for token metadata
    string private _baseTokenURI;
    /// @notice Address of the gacha contract authorized to mint Monkeys
    address public gachaContract;
    /// @notice Counter for minted token IDs
    uint256 private _tokenIdCounter;

    /// @notice Maps token ID to owner address
    mapping(uint256 => address) private _owners;
    /// @notice Maps owner address to token count
    mapping(address => uint256) private _balances;
    /// @notice Maps token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;
    /// @notice Maps owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    /// @notice Maps token ID to Monkey data
    mapping(uint256 => Monkey) private _monkeys;

    /**
     * @notice Enumeration defining possible rarity levels
     * @dev Used to determine Monkey stats and abilities
     */
    enum Rarity {
        Common,
        Rare,
        Epic,
        Legendary
    }

    /**
     * @notice Enumeration defining possible element types
     * @dev Used in battle mechanics for type advantages
     */
    enum PowerType {
        Fire,
        Water,
        Grass
    }

    /**
     * @notice Structure containing Monkey attributes
     * @param id Unique identifier of the Monkey
     * @param name Name of the Monkey
     * @param rarity Rarity level of the Monkey
     * @param powerType Element type of the Monkey
     * @param attack Attack stat of the Monkey
     * @param health Health stat of the Monkey
     */
    struct Monkey {
        uint256 id;
        string name;
        Rarity rarity;
        PowerType powerType;
        uint256 attack;
        uint256 health;
    }

    /**
     * @notice Initializes the Monkeys NFT contract
     * @dev Sets up initial values and registers ERC165 interfaces
     * @param _gachaContract Address of the gacha contract
     * @param baseURI Base URI for token metadata
     */
    constructor(address _gachaContract, string memory baseURI) Ownable() {
        _name = "Monkey Brothers";
        _symbol = "MONKBRO";
        _baseTokenURI = baseURI;

        if (_gachaContract != address(0)) {
            gachaContract = _gachaContract;
        }

        // Register the supported interfaces
        _registerInterface(type(IERC721).interfaceId);
        _registerInterface(type(IERC721Metadata).interfaceId);
    }

    /// @notice Emitted when the gacha contract address is updated
    event GachaContractUpdated(
        address indexed oldGacha,
        address indexed newGacha
    );

    /// @notice Emitted when the base URI is updated
    event BaseURIUpdated(string oldURI, string newBaseURI);

    /// @notice Emitted when a new Monkey is created
    event MonkeyCreated(
        uint256 indexed tokenId,
        string name,
        Rarity rarity,
        PowerType powerType
    );

    // ERC721Metadata implementation
    /**
     * @notice Returns the name of the token collection
     * @return string Name of the collection
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @notice Returns the symbol of the token collection
     * @return string Symbol of the collection
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Returns the metadata URI for a given token
     * @param tokenId ID of the token to get URI for
     * @return string Metadata URI for the token
     */
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        string memory baseURI = _baseURI();
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, toString(tokenId), ".json"))
                : "";
    }

    /**
     * @notice Updates the base URI for token metadata
     * @dev Only callable by contract owner
     * @param newBaseURI New base URI to set
     */
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        require(bytes(newBaseURI).length > 0, "Empty base URI");
        string memory oldURI = _baseTokenURI;
        _baseTokenURI = newBaseURI;
        emit BaseURIUpdated(oldURI, newBaseURI);
    }

    /**
     * @notice Updates the gacha contract address
     * @dev Only callable by contract owner
     * @param _newGachaContract New gacha contract address
     */
    function setGachaContract(address _newGachaContract) external onlyOwner {
        require(_newGachaContract != address(0), "Invalid gacha address");
        emit GachaContractUpdated(gachaContract, _newGachaContract);
        gachaContract = _newGachaContract;
    }

    // ERC721 implementation
    /**
     * @notice Gets the balance of tokens owned by an address
     * @dev Throws if the address is zero
     * @param owner Address to query balance for
     * @return uint256 Number of tokens owned by the address
     */
    function balanceOf(
        address owner
    ) public view virtual override returns (uint256) {
        require(
            owner != address(0),
            "ERC721: Address zero is not a valid owner"
        );
        return _balances[owner];
    }

    /**
     * @notice Gets the owner of a specific token
     * @dev Throws if the token does not exist
     * @param tokenId ID of the token to query
     * @return address Current owner of the token
     */
    function ownerOf(
        uint256 tokenId
    ) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: Invalid token ID");
        return owner;
    }

    /**
     * @notice Approves an address to transfer a specific token
     * @dev Caller must be owner or approved operator
     * @param to Address to be approved
     * @param tokenId ID of the token to be approved
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ownerOf(tokenId);
        require(to != owner, "ERC721: Approval to current owner");
        require(
            msg.sender == owner || isApprovedForAll(owner, msg.sender),
            "ERC721: Approve caller is not token owner or approved for all"
        );
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    /**
     * @notice Sets or unsets an operator as approved for all tokens
     * @dev Allows/disallows operator to manage all of msg.sender's tokens
     * @param operator Address to modify approval status for
     * @param approved True to approve, false to revoke approval
     */
    function setApprovalForAll(
        address operator,
        bool approved
    ) public virtual override {
        require(msg.sender != operator, "ERC721: Approve to caller");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @notice Gets the approved address for a token
     * @dev Throws if the token does not exist
     * @param tokenId ID of the token to query
     * @return address Currently approved address for the token
     */
    function getApproved(
        uint256 tokenId
    ) public view virtual override returns (address) {
        require(
            _exists(tokenId),
            "ERC721: Approved query for nonexistent token"
        );
        return _tokenApprovals[tokenId];
    }

    /**
     * @notice Checks if an operator is approved for all tokens of an owner
     * @param owner Address that owns the tokens
     * @param operator Address to check approval status for
     * @return bool True if the operator is approved for all tokens
     */
    function isApprovedForAll(
        address owner,
        address operator
    ) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @notice Transfers a token between addresses
     * @dev Caller must be owner or approved
     * @param from Address to transfer from
     * @param to Address to transfer to
     * @param tokenId ID of the token to transfer
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "ERC721: Caller is not token owner or approved"
        );
        _transfer(from, to, tokenId);
    }

    /**
     * @notice Safely transfers a token between addresses
     * @dev Calls safeTransferFrom with empty data
     * @param from Address to transfer from
     * @param to Address to transfer to
     * @param tokenId ID of the token to transfer
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @notice Safely transfers a token between addresses with additional data
     * @dev Checks if receiver is a contract and if it can handle ERC721 tokens
     * @param from Address to transfer from
     * @param to Address to transfer to
     * @param tokenId ID of the token to transfer
     * @param data Additional data to pass to receiver contract
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "ERC721: Caller is not token owner or approved"
        );
        _safeTransfer(from, to, tokenId, data);
    }

    /**
     * @notice Mints a new Monkey NFT with specified attributes
     * @dev Only callable by the gacha contract
     * @param to Address to receive the minted Monkey
     * @param monkeyName Name of the new Monkey
     * @param rarity Rarity level (0=Common, 1=Rare, 2=Epic, 3=Legendary)
     * @param powerType Element type (0=Fire, 1=Water, 2=Grass)
     * @param attack Attack stat value of the Monkey
     * @param health Health stat value of the Monkey
     * @return uint256 ID of the newly minted Monkey
     */
    function mintMonkey(
        address to,
        string memory monkeyName,
        uint8 rarity,
        uint8 powerType,
        uint256 attack,
        uint256 health
    ) external returns (uint256) {
        require(msg.sender == gachaContract);
        require(to != address(0), "Cannot mint to zero address");
        require(rarity <= uint8(Rarity.Legendary), "Invalid rarity");
        require(powerType <= uint8(PowerType.Grass), "Invalid power type");

        uint256 tokenId = _tokenIdCounter;
        _mint(to, tokenId);

        _monkeys[tokenId] = Monkey({
            id: tokenId,
            name: monkeyName,
            rarity: Rarity(rarity),
            powerType: PowerType(powerType),
            attack: attack,
            health: health
        });

        _tokenIdCounter++;
        emit MonkeyCreated(
            tokenId,
            monkeyName,
            Rarity(rarity),
            PowerType(powerType)
        );
        return tokenId;
    }

    // Internal functions
    /**
     * @notice Returns the base URI for token metadata
     * @dev Internal function to get the base URI, can be overridden
     * @return string The base URI string
     */
    function _baseURI() internal view virtual returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @notice Checks if a token ID exists
     * @dev Internal function to verify token existence
     * @param tokenId ID of the token to check
     * @return bool True if the token exists, false otherwise
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @notice Checks if an address is the owner or approved for a token
     * @dev Used internally to validate transfer permissions
     * @param spender Address to check permissions for
     * @param tokenId ID of the token to check
     * @return bool True if spender is owner or approved
     */
    function _isApprovedOrOwner(
        address spender,
        uint256 tokenId
    ) internal view virtual returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner ||
            isApprovedForAll(owner, spender) ||
            getApproved(tokenId) == spender);
    }

    /**
     * @notice Internal function to mint a new token
     * @dev Creates new token and assigns it to recipient
     * @param to Address to mint token to
     * @param tokenId ID of the token to mint
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC 721: mint to zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @notice Internal function to perform token transfer
     * @dev Updates balances and ownership mappings
     * @param from Address to transfer from
     * @param to Address to transfer to
     * @param tokenId ID of the token to transfer
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(
            ownerOf(tokenId) == from,
            "ERC721: transfer from incorrect owner"
        );
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @notice Safely transfers a token with additional checks
     * @dev Adds safe transfer checks to normal transfer
     * @param from Address to transfer from
     * @param to Address to transfer to
     * @param tokenId ID of the token to transfer
     * @param data Additional data to pass to receiver contract
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(
            _checkOnERC721Received(from, to, tokenId, data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @notice Hook that is called before any token transfer
     * @dev Can be overridden to add custom transfer logic
     * @param from Address tokens are transferred from
     * @param to Address tokens are transferred to
     * @param tokenId ID of the token being transferred
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    /**
     * @notice Hook that is called after any token transfer
     * @dev Can be overridden to add custom post-transfer logic
     * @param from Address tokens are transferred from
     * @param to Address tokens are transferred to
     * @param tokenId ID of the token being transferred
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    /**
     * @notice Checks if a contract can receive ERC721 tokens
     * @dev Makes sure contract recipients are aware of ERC721 protocol
     * @param from Address tokens are transferred from
     * @param to Address tokens are transferred to
     * @param tokenId ID of the token being transferred
     * @param data Additional data passed with transfer
     * @return bool Whether the transfer can proceed
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.code.length > 0) {
            try
                IERC721Receiver(to).onERC721Received(
                    msg.sender,
                    from,
                    tokenId,
                    data
                )
            returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert(
                        "ERC721: transfer to non ERC721Receiver implementer"
                    );
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @notice Converts a uint256 value to its string representation
     * @dev Internal pure function for number to string conversion
     * @param value The number to convert
     * @return string The string representation of the number
     */
    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @notice Retrieves the attributes of a specific Monkey
     * @dev Returns full Monkey struct with all attributes
     * @param tokenId ID of the Monkey to query
     * @return Monkey struct containing all Monkey data
     */
    function getMonkey(uint256 tokenId) public view returns (Monkey memory) {
        require(_exists(tokenId), "Monkey does not exist");
        return _monkeys[tokenId];
    }

    /**
     * @notice Gets the total number of Monkeys that have been minted
     * @dev Returns the current token ID counter value
     * @return uint256 Total number of minted Monkeys
     */
    function getTotalMinted() public view returns (uint256) {
        return _tokenIdCounter;
    }
}
