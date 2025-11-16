// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./ERC20.sol";

/**
 * @title MockUSDC
 * @notice Mock USDC token for testing purposes
 * @dev Mimics USDC with 6 decimals
 */
contract MockUSDC is ERC20 {
    uint8 private constant DECIMALS = 6;
    
    constructor() ERC20("Mock USDC", "USDC") {
        // Mint initial supply to deployer (1 million USDC)
        _mint(msg.sender, 1_000_000 * 10**DECIMALS);
    }
    
    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }
    
    /**
     * @notice Mint tokens for testing
     * @param to Address to mint to
     * @param amount Amount to mint (in 6 decimal format)
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
