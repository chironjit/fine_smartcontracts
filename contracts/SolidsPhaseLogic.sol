pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface FineNFTInterface {
    function mint(address to) external returns (uint);
    function mintBonus(address to, uint infiniteId) external returns (uint);
    function getArtistAddress() external view returns (address payable);
    function getAdditionalPayee() external view returns (address payable);
    function getAdditionalPayeePercentage() external view returns (uint);
    function getTokenLimit() external view returns (uint);
    function checkPool() external view returns (uint);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
}

interface IDelegationRegistry {

}

contract SolidsLogic is AccessControl{
    enum CurrentPhase {
        OG,
        AL,
        Open,
        Owner
    }

    struct PhaseSupply{
        uint32 currentSupply; //stores current phase for easier retrieval
        uint32 phase1MaxSupply; // OG - already minted
        uint32 phase2MaxSupply; // Allowlist only
        uint32 phase3MaxSupply; // Public mint
        uint32 phase4MaxSupply; // Reserved for owner
    }

    PhaseSupply public phaseSupply;

    uint public immutable MAX_SUPPLY = 6000;
    
    address public immutable solidsContractAddress = 0xAFf167337289eDB939cf52c2bE434885dB50abe9;
    address public artistAddress;
    address public callerAddress;

    CurrentPhase public currentPhase = CurrentPhase.OG;

    uint public openPrice = 0.2 ether;
    

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function resetPhaseSupply(uint _phase2Supply, uint _phase3Supply, uint _phase4Supply) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint alreadyMinted = IERC20(solidsContractAddress).totalSupply();
        if(alreadyMinted + _phase2Supply + _phase3Supply + _phase4Supply != MAX_SUPPLY) {revert("Sum & max supply mismatch");}
        phaseSupply = PhaseSupply({
            currentSupply: alreadyMinted,
            phase1MaxSupply: uint32(1528),
            phase2MaxSupply: uint32(1528 + _phase2Supply),
            phase3MaxSupply: uint32(1528 + _phase2Supply + _phase3Supply),
            phase4MaxSupply: uint32(MAX_SUPPLY)
        });
    }

    function setPhase(CurrentPhase _phase) external onlyRole(DEFAULT_ADMIN_ROLE) {
        currentPhase = CurrentPhase._phase;
    }

    function setArtistAddress(address _artistAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        artistAddress = _artistAddress;
    }

    function setCallerAddress(address _callerAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        callerAddress = _callerAddress;
    }

    function callMintLogic(address requester, address receiver, address, uint amount) external nonReentrant returns (bool minted, uint totalPriceToCharge) {
        require(msg.sender == callerAddress, "Caller not approved")
        CurrentPhase memory phase = currentPhase;
        PhaseSupply memory sup = phaseSupply;
        if (phase == CurrentPhase.AL) {
            require(sup.currentSupply <= sup.phase2MaxSupply, "Phase sold out");
            uint availableToMint = sup.phase2MaxSupply - sup.currentSupply;
            uint amountToMint = availableToMint > amount ? amount : availableToMint;
            if(requester == receiver) {
                alMint(requester, amountToMint);
            } else {
                delegateCashCheckMint(requester, receiver, amountToMint);
            }
            sup.currentSupply = sup.currentSupply + amountToMint;
        }
        
        if (phase == CurrentPhase.Open) {
            require(sup.currentSupply <= sup.phase3MaxSupply, "Phase sold out");
            uint availableToMint = sup.phase3MaxSupply - sup.currentSupply;
            uint amountToMint = availableToMint > amount ? amount : availableToMint;
            totalPriceToCharge =  openPrice * amountToMint;
            openMint(receiver, amountToMint);
            sup.currentSupply = sup.currentSupply + amountToMint;
        }

        if (phase == CurrentPhase.Owner) {
            require(sup.currentSupply <= sup.phase4MaxSupply, "Minted out");
            require(receiver == artistAddress, "Not owner");
            uint availableToMint = sup.phase4MaxSupply - sup.currentSupply;
            uint amountToMint = availableToMint > amount ? amount : availableToMint;
            sup.currentSupply = sup.currentSupply + amountToMint;
        }

        phaseSupply = sup;
        return (true, totalPriceToCharge);


    }



    function alMint(address _receiver, uint _amountToMint) internal {
        // logic to check 

        for (uint i; i < _amountToMint; ++ i) {
            IERC20(solidsContractAddress).mint(_receiver);
        }
    }

    function delegateCashCheckMint(address _requester, address _vault, uint _amountToMint) internal {
        if (_vault != address(0)) { 
            bool isDelegateValid = dc.checkDelegateForContract(requester, _vault, solidsContractAddress);
            require(isDelegateValid, "invalid delegate-vault pairing");
            _requester = _vault;
        }

        alMint(_requester, _amountToMint);
    }

    function openMint(address _receiver, uint _amountToMint) internal {
        for (uint i; i < _amountToMint; ++ i) {
            IERC20(solidsContractAddress).mint(_receiver);
        }
    }

    function ownerMint(address receiver, uint amountToMint) internal {
        for (uint i; i < _amountToMint; ++ i) {
            IERC20(solidsContractAddress).mint(_receiver);
        }
    }

}