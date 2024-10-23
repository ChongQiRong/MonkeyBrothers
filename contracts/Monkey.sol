// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC165/ERC165.sol";
import "../contracts/ERC721/IERC721.sol";
import "../contracts/ERC721/IERC721Metadata.sol";
import "../contracts/ERC721/IERC721Receiver.sol";

contract Monkeys is ERC165, IERC721, IERC721Metadata {
    // Token name
    string private _name;
    // Token symbol
    string private _symbol;
    // Base URI for metadata
    string private _baseTokenURI;

    //Token ID to owner address
    mapping(uint256 => address) private _owners;
    //Owner address to token count
    mapping(address => uint256) private _balances;
    //Token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;
    //Owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    //CardId to Monkey
    mapping(address => mapping(uint256 => Monkey)) _monkeys;
    //CardId to URI
    mapping(uint256 => string) _tokenUris;

    // Counter for token IDs
    uint256 private _tokenIdCounter;

    enum Rarity { Common, Rare, Epic, Legendary }
    enum PowerType { Fire, Water, Earth}

    //Structure for properties of each Monkey card
    struct Monkey {
        uint256 id;
        string name;
        Rarity rarity;
        PowerType powerType;
        uint256 attack;
        uint256 health;
    }

    constructor() {
        _name = "Monkey Brothers";
        _symbol = "MONKBRO";
        _baseTokenURI = "";

        // Register the supported interfaces
        _registerInterface(type(IERC721).interfaceId);
        _registerInterface(type(IERC721Metadata).interfaceId);
    }

    // ERC721Metadata implementation
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, toString(tokenId))) : "";
    }

    // ERC721 implementation
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: Address zero is not a valid owner");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: Invalid token ID");
        return owner;
    }

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

    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(msg.sender != operator, "ERC721: Approve to caller");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: Approved query for nonexistent token");
        return _tokenApprovals[tokenId];
    }

    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: Caller is not token owner or approved");
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual override {
        require(_isApprovedOrOwner(msg.sender, tokenId), "ERC721: Caller is not token owner or approved");
        _safeTransfer(from, to, tokenId, data);
    }

    // Public minting function
    // function mint() public returns (uint256) {
    //     uint256 tokenId = _tokenIdCounter;
    //     _mint(msg.sender, tokenId);
    //     _tokenIdCounter++;
    //     return tokenId;
    // }

    // Internal functions
    function _baseURI() internal view virtual returns (string memory) {
        return _baseTokenURI;
    }

    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    // function _mint(address to, uint256 tokenId) internal virtual {
    //     require(to != address(0), "ERC721: mint to the zero address");
    //     require(!_exists(tokenId), "ERC721: token already minted");

    //     _balances[to] += 1;
    //     _owners[tokenId] = to;

    //     emit Transfer(address(0), to, tokenId);
    // }

    function _transfer(address from, address to, uint256 tokenId) internal virtual {
        require(ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}

    function _afterTokenTransfer(address from, address to, uint256 tokenId) internal virtual {}

    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.code.length > 0) {
            try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
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

    // Utility function to convert uint to string
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
}