// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface RandomizerInt {
    function returnValue() external view returns (bytes32);
}

enum EntropySource {
    Internal,
    External
}

struct FineCoreSettings {
    address payable fineTreasury;
    uint16 platformPercentage;
    uint16 platformRoyalty;
    EntropySource entropySetting;
}


contract FineCore is AccessControl {
    using Counters for Counters.Counter;

    RandomizerInt entropySource;
    Counters.Counter private _projectCounter;
    mapping(uint => address) public projects;
    mapping(address => bool) public allowlist;

    FineCoreSettings public settings;
    
    constructor(address payable _treasury, uint _platformPercentage, uint _platformRoyalty) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        FineCoreSettings memory set;
        set.fineTreasury = _treasury;
        set.platformPercentage = uint16(_platformPercentage);
        set.platformRoyalty = uint16(_platformRoyalty);
        settings = set;
    }

    // Core Mgmt Functions

    /**
     * @dev Update the treasury address
     * @param _treasury address to set
     * @dev Only the admin can call this
     */
    function setTreasury(address payable _treasury) onlyRole(DEFAULT_ADMIN_ROLE) external {
        settings.fineTreasury = _treasury;
    }

    function getTreasury() external view returns (address payable) {
        return settings.fineTreasury;
    }

    /**
     * @dev Update the platform percentage
     * @param _percentage for royalties
     * @dev Only the admin can call this
     */
    function setPlatformPercent(uint _percentage) onlyRole(DEFAULT_ADMIN_ROLE) external {
        require(_percentage < 10000, "Value not valid");
        settings.platformPercentage = uint16(_percentage);
    }

    function getPlatformPercent() external view returns (uint) {
        return settings.platformPercentage;
    }

    /**
     * @dev Update the royalty percentage
     * @param _percentage for royalties
     * @dev Only the admin can call this
     */
    function setRoyaltyPercent(uint _percentage) onlyRole(DEFAULT_ADMIN_ROLE) external {
        require(_percentage < 10000, "Value not valid");
        settings.platformRoyalty = uint16(_percentage);
    }

    function getRoyaltyPercentage() external view returns (uint) {
        return settings.platformRoyalty;
    }


    // Project Mgmt Functions

    /**
     * @dev add a project
     * @param project address of the project contract
     * @dev Only the admin can call this
     */
    function addProject(address project) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint id = _projectCounter.current();
        _projectCounter.increment();
        projects[id] = project;
        allowlist[project] = true;
    }
    
    /**
     * @dev rollback last project add
     * @dev Only the admin can call this
     */
    function rollbackLastProject() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _projectCounter.decrement();
        uint id = _projectCounter.current();
        address project = projects[id];
        allowlist[project] = false;
    }

    /**
     * @dev lookup a projects address by id
     * @param id of the project to retrieve
     */
    function getProjectAddress(uint id) external view returns (address) {
        return projects[id];
    }

    // Randomizer

    /**
     * @dev set Randomizer
     */
    function setExternalEntropySource(address rand) external onlyRole(DEFAULT_ADMIN_ROLE) {
        entropySource = RandomizerInt(rand);
        settings.entropySetting = EntropySource.External;
    }

    /**
     * @dev test external Randomizer
     */
    function testExternalRandom() external view onlyRole(DEFAULT_ADMIN_ROLE) returns (bytes32) {
        return entropySource.returnValue();
    }

    /**
     * @dev External random call
     */

    function externalRandom() internal view returns (bytes32) {
        return entropySource.returnValue();
    }

    /**
     * @dev Internal random call
     */
    function internalRandom() internal view returns (bytes32) {
        return bytes32(block.prevrandao);
    }

    /**
     * @dev Call the Randomizer and get some randomness
     */
    function getRandomness(uint256 id, uint256 seed)
        external view returns (uint256 randomnesss)
    {
        require(allowlist[msg.sender], "rng caller not allow listed");

        bytes32 entropy = (settings.entropySetting == EntropySource.Internal) ? internalRandom() : externalRandom();

        uint256 randomness = uint256(keccak256(abi.encodePacked(
            entropy,
            id,
            seed
        )));
        return randomness;
    }
}