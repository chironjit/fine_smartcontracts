// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./FineCoreInterface.sol";

interface FineNFTInterface {
    function mint(address to) external returns (uint);
    function mintBonus(address to, uint infiniteId) external returns (uint);
    function getArtistAddress() external view returns (address payable);
    function getAdditionalPayee() external view returns (address payable);
    function getAdditionalPayeePercentage() external view returns (uint256);
    function getTokenLimit() external view returns (uint256);
    function checkPool() external view returns (uint);
    function totalSupply() external view returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
}

interface BasicNFTInterface {
    function ownerOf(uint256 tokenId) external view returns (address);
    function balanceOf(address owner) external view returns (uint256);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
}

interface MintLogicInterface {
    function callMintLogic(address requester, address receiver, address nftContractAddress, uint amount) external returns (bool minted, uint totalPriceToCharge);
}

enum SalePhase {
  Closed,
  PreSale,
  PublicSale,
  Custom,
  Owner
}


contract FineShop is AccessControl, ReentrancyGuard {
    struct Project {
        bytes12 projectName;
        address projectAddress;
        address payable owner;
        bytes12 paymentCurrency; // of the ERC20 payment token (if not ETH)
        address currencyAddress; // of the ERC20 payment token (if not ETH)
        uint96 purchasePrice;
        address logicAddress; // used when custom logic is required
        uint96 maxMint;
    }

    Project[] public projects;
    uint public projectCount; // keeps track of the number of projects
    mapping(uint projectId => bool) public isLive;

    error NotProjectOwner(string message);
    error ProjectNotLive();

    // mapping (uint projectId)

    FineCoreInterface fineCore;
    MintLogicInterface mintLogic;

    constructor(address _fineCoreAddresss) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        fineCore = FineCoreInterface(_fineCoreAddresss);
    }

    // Project Owner Functions
    modifier isLive(uint _projectId) {
      require(isLive[_projectId] == 2, "Project not yet live");
      _;
    }

    function quickProjectInit (string calldata _name, address _nftContractAddress, address payable _owner) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_nftContractAddress != address(0) && _owner != address(0), "Can't be zero address");
        projects.push(Project({
            projectName: _name,
            projectAddress: _nftContractAddress,
            owner: _owner
        }));
        isLive[projectCount] = 1;
        ++projectCount;        
    }

    function projectInit (
        string calldata _name, 
        address _nftContractAddress, 
        address payable _owner, 
        string calldata _paymentCurrency, 
        address _currencyAddress, 
        uint _purchasePrice, 
        address _logicAddress,
        uint _maxMintLimit
        ) external onlyRole(DEFAULT_ADMIN_ROLE) {
            require(_nftContractAddress != address(0) && _owner != address(0), "Can't be zero address");
            projects.push(Project({
                projectName: _name,
                projectAddress: _nftContractAddress,
                owner: _owner,
                paymentCurrency: _paymentCurrency,
                currencyAddress: _currencyAddress,
                purchasePrice: uint96(_purchasePrice),
                logicAddress: _logicAddress,
                maxMint: uint96(maxMintLimit)
        }));
        isLive[projectCount] = 1;
        ++projectCount;
    }

    /**
     * @dev set the owner of a project
     * @param _projectId to set owner of
     * @param newOwner to set as owner
     */

    function setNewOwner(uint _projectId, address _newOwner) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Project memory proj = projects[_projectId];
        require(proj.owner != _newOwner, "Can't be same owner");
        require(_newOwner != address(0), "owner can't be zero address");
        proj.owner = newOwner;
        projects[_projectId] = proj;
    }


    /**
     * @dev set the currency to "ETH" with address(0) for ETH or specify the name and address of the erc20 token
     * @param _projectId to set currency of
     */
    function setNewCurrency(string calldata _paymentCurrency, address _currencyAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Project memory proj = projects[_projectId];
        require(_currencyAddress != address(0), "owner can't be zero address");
        proj.paymentCurrency = _paymentCurrency;
        proj.currencyAddress = _currencyAddress;
        projects[_projectId] = proj;
    }

    /**
     * @dev Toggle between live and closed state in the project. Value of 2 and 1 
     * @param _projectId to push live
     */
    function toggleGoLive(uint _projectId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        isLive[_projectId] = 1 ? 2 : 1;
    }

    /**
     * @dev set the mint limiter of a project
     * @param _projectId project to set mint limit of
     * @param _limit mint limit per address
     */
    function setProjectMintLimit(uint256 _projectId, uint8 _limit) public onlyRole(DEFAULT_ADMIN_ROLE) {
        Project storage proj = projects[_projectId];
        proj.maxMint = uint96(_limit);
    }

    /**
     * @dev set the price of a project
     * @param _projectId to set price of
     * @param price to set project to
     */
    function setPrice(uint _projectId, uint _price) external onlyOwner(_projectId) notLive(_projectId) {
        Project storage proj = projects[_projectId];
        proj.purchasePrice = uint96(_price);
    }


    // Payment helper function
    // use payment helper function if the mint is a direct mint
    // otherwise just send on value

    function directMint(address _receiver, address _nftContractAddress, uint _amount) internal {
        for (uint i; i < _amount; ++ i) {
            IERC20(_nftContractAddress).mint(_receiver);
        }
    }


    function logicMint(address _requester, address _receiver, address _nftContractAddress, uint _amount, address _mintLogicAddress) internal {
        return mintLogic(_mintLogicAddress).callMintLogic(_requester, _receiver, _nftContractAddress, _amount);
    }


    /**
     * @dev purchase tokens of a project
     * @param _projectId to purchase
     * @param count number of tokens to purchase
     */
    function buy(uint _projectId, address _to, uint _count) external payable onReentrant returns (string memory) {
        if(isLive[_projectId] != 2) {revert ProjectNotLive();}
        Project storage proj = projects[_projectId];
        if(proj.logicAddress != address(0)) {
            (minted, totalPrice) = logicMint(msg.sender, _to, proj.projectAddress, _amount, proj.logicAddress);
        } else {
            directMint(_to, proj.projectAddress, _count);
        }
    }

  // To complete:

 // payment process




}
