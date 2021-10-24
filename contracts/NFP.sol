pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

error MaximumSupplyReached();
error NotEnoughTip();
error Forbidden();
error ZeroAddressNewOwner();
error CouldNotWithdraw();
error ZeroMaximumSupply();
error ZeroPaidMintingCost();
error NotEnoughNativeCurrency();
error MintingLimitReached();
error WhitelistMerkleRootNotSet();
error AlreadyClaimed();
error InvalidMerkleProof();
error AmountTooHigh();
error TokenNotOwned();
error InvalidERC721();
error InvalidERC1155();
error InvalidBaseUri();

/**
 * @title NFP
 * @dev NFP contract
 * @author Federico Luzzi - <fedeluzzi00@gmail.com>
 * SPDX-License-Identifier: GPL-3.0
 */
contract NFP is ERC721 {
    struct Mintable {
        uint256 paid;
        uint256 free;
        uint256 whitelist;
    }

    struct Minted {
        uint256 paid;
        uint256 free;
        uint256 whitelist;
    }

    struct Foreground {
        address token;
        uint256 id;
    }

    struct Minter {
        uint256 paid;
        bool free;
        bool whitelist;
    }

    address public owner;
    uint256 public paidMintingCost;
    uint256 internal tokenIdTracker;
    bytes32 internal whitelistMerkleRoot;
    string public baseUri;
    Minted public minted;
    Mintable public mintable;
    mapping(address => Minter) public minter;
    mapping(uint256 => Foreground) public foreground;

    event OwnershipTransferred(address previousOwner, address newOwner);
    event PaidMintingCostUpdated(
        uint256 oldPaidMintingCost,
        uint256 newPaidMintingCost
    );
    event Withdrawn(uint256 nativeCurrencyAmount);
    event WhitelistMerkleRootUpdated(
        bytes32 oldWhitelistMerkleRoot,
        bytes32 newWhitelistMerkleRoot
    );
    event SetForegroundNFT(
        uint256 id,
        address foregroundToken,
        uint256 foregroundId
    );
    event BaseUriUpdated(string oldBaseUri, string newBaseUri);

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _paidMintingCost,
        uint256 _freeMintable,
        uint256 _paidMintable,
        uint256 _whitelistMintable,
        string memory _baseUri
    ) ERC721(_name, _symbol) {
        if (_freeMintable + _whitelistMintable + _paidMintable == 0)
            revert ZeroMaximumSupply();
        if (_paidMintingCost == 0) revert ZeroPaidMintingCost();
        if (bytes(_baseUri).length == 0) revert InvalidBaseUri();
        owner = msg.sender;
        paidMintingCost = _paidMintingCost;
        baseUri = _baseUri;
        mintable = Mintable({
            paid: _paidMintable,
            free: _freeMintable,
            whitelist: _whitelistMintable
        });
    }

    function transferOwnership(address _newOwner) external {
        if (msg.sender != owner) revert Forbidden();
        if (_newOwner == address(0)) revert ZeroAddressNewOwner();
        owner = _newOwner;
        emit OwnershipTransferred(msg.sender, _newOwner);
    }

    function setMintingCost(uint256 _newPaidMintingCost) external {
        if (msg.sender != owner) revert Forbidden();
        emit PaidMintingCostUpdated(paidMintingCost, _newPaidMintingCost);
        paidMintingCost = _newPaidMintingCost;
    }

    function setWhitelistMerkleRoot(bytes32 _newWhitelistMerkleRoot) external {
        if (msg.sender != owner) revert Forbidden();
        emit WhitelistMerkleRootUpdated(
            whitelistMerkleRoot,
            _newWhitelistMerkleRoot
        );
        whitelistMerkleRoot = _newWhitelistMerkleRoot;
    }

    function setBaseUri(string calldata _newBaseUri) external {
        if (msg.sender != owner) revert Forbidden();
        emit BaseUriUpdated(baseUri, _newBaseUri);
        baseUri = _newBaseUri;
    }

    function freeMint() external {
        Minter storage _minter = minter[msg.sender];
        if (_minter.free) revert MintingLimitReached();
        if (minted.free == mintable.free) revert MaximumSupplyReached();
        uint256 _tokenId = tokenIdTracker++;
        _mint(msg.sender, _tokenId);
        minted.free++;
        _minter.free = true;
    }

    function setForegroundERC721(
        uint256 _id,
        address _erc721,
        uint256 _erc721Id
    ) external {
        if (ownerOf(_id) != msg.sender) revert TokenNotOwned();
        if (IERC721(_erc721).ownerOf(_erc721Id) != msg.sender)
            revert InvalidERC721();
        foreground[_id].token = _erc721;
        foreground[_id].id = _erc721Id;
        emit SetForegroundNFT(_id, _erc721, _erc721Id);
    }

    function setForegroundERC1155(
        uint256 _id,
        address _erc1155,
        uint256 _erc1155Id
    ) external {
        if (ownerOf(_id) != msg.sender) revert TokenNotOwned();
        if (IERC1155(_erc1155).balanceOf(msg.sender, _erc1155Id) == 0)
            revert InvalidERC1155();
        foreground[_id].token = _erc1155;
        foreground[_id].id = _erc1155Id;
        emit SetForegroundNFT(_id, _erc1155, _erc1155Id);
    }

    function _beforeTokenTransfer(
        address,
        address,
        uint256 _tokenId
    ) internal override {
        foreground[_tokenId].token = address(0);
        foreground[_tokenId].id = 0;
    }

    function paidMint(uint256 _amount) external payable {
        if (minted.paid == mintable.paid) revert MaximumSupplyReached();
        if (msg.value < paidMintingCost * _amount)
            revert NotEnoughNativeCurrency();
        Minter storage _minter = minter[msg.sender];
        if (_amount + _minter.paid > 3) revert AmountTooHigh();
        if (_minter.paid == 3) revert MintingLimitReached();
        for (uint256 _i = 0; _i < _amount; _i++) {
            _mint(msg.sender, tokenIdTracker++);
            minted.paid++;
            _minter.paid++;
        }
    }

    function whitelistedMint(bytes32[] calldata _proof) external payable {
        if (whitelistMerkleRoot == bytes32(""))
            revert WhitelistMerkleRootNotSet();
        Minter storage _minter = minter[msg.sender];
        if (_minter.whitelist) revert AlreadyClaimed();
        bytes32 _leaf = keccak256(abi.encodePacked(msg.sender));
        if (!MerkleProof.verify(_proof, whitelistMerkleRoot, _leaf))
            revert InvalidMerkleProof();
        _mint(msg.sender, tokenIdTracker++);
        minted.whitelist++;
        _minter.whitelist = true;
    }

    function withdrawNativeCurrency() external {
        if (msg.sender != owner) revert Forbidden();
        uint256 _nativeCurrencyAmount = address(this).balance;
        (bool _sent, ) = payable(owner).call{value: _nativeCurrencyAmount}("");
        if (!_sent) revert CouldNotWithdraw();
        emit Withdrawn(_nativeCurrencyAmount);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseUri;
    }
}
