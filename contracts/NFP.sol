pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
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

    struct Minter {
        uint256 paid;
        bool free;
        bool whitelist;
    }

    address public owner;
    uint256 public paidMintingCost;
    uint256 internal tokenIdTracker;
    bytes32 internal whitelistMerkleRoot;
    Minted public minted;
    Mintable public mintable;
    mapping(address => Minter) internal minter;

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

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _paidMintingCost,
        uint256 _freeMintable,
        uint256 _paidMintable,
        uint256 _whitelistMintable
    ) ERC721(_name, _symbol) {
        if (_freeMintable + _whitelistMintable + _paidMintable == 0)
            revert ZeroMaximumSupply();
        if (_paidMintingCost == 0) revert ZeroPaidMintingCost();
        owner = msg.sender;
        paidMintingCost = _paidMintingCost;
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

    function freeMint() external {
        Minter storage _minter = minter[msg.sender];
        if (_minter.free) revert MintingLimitReached();
        if (minted.free == mintable.free) revert MaximumSupplyReached();
        // TODO: test that increment is done after assigning the old value to the var
        uint256 _tokenId = tokenIdTracker++;
        _safeMint(msg.sender, _tokenId);
        minted.free++;
        _minter.free = true;
    }

    function paidMint() external payable {
        if (minted.paid == mintable.paid) revert MaximumSupplyReached();
        if (msg.value < paidMintingCost) revert NotEnoughNativeCurrency();
        Minter storage _minter = minter[msg.sender];
        if (_minter.paid == 3) revert MintingLimitReached();
        uint256 _tokenId = tokenIdTracker++;
        _safeMint(msg.sender, _tokenId);
        minted.paid++;
        _minter.paid++;
    }

    function whitelistedMint(bytes32[] calldata _proof) external payable {
        if (whitelistMerkleRoot == bytes32(""))
            revert WhitelistMerkleRootNotSet();
        Minter storage _minter = minter[msg.sender];
        if (_minter.whitelist) revert AlreadyClaimed();
        bytes32 _leaf = keccak256(abi.encodePacked(msg.sender));
        if (!MerkleProof.verify(_proof, whitelistMerkleRoot, _leaf))
            revert InvalidMerkleProof();
        uint256 _tokenId = tokenIdTracker++;
        _safeMint(msg.sender, _tokenId);
        minted.whitelist++;
        _minter.whitelist = true;
        emit Transfer(address(0), msg.sender, _tokenId);
    }

    function withdrawNativeCurrency() external {
        if (msg.sender != owner) revert Forbidden();
        uint256 _nativeCurrencyAmount = address(this).balance;
        (bool _sent, ) = payable(owner).call{value: _nativeCurrencyAmount}("");
        if (!_sent) revert CouldNotWithdraw();
        emit Withdrawn(_nativeCurrencyAmount);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://test.io/";
    }
}
