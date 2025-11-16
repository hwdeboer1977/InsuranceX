# InsuranceX - Unemployment Benefit Smart Contract

A proof-of-concept smart contract for managing unemployment benefits on Arbitrum, inspired by the Dutch unemployment insurance system.

⚠️ **WORK IN PROGRESS** - This is a POC for testing and learning purposes only.

## Overview

InsuranceX allows employers to pool premiums and provides unemployment benefits to eligible employees through a transparent, blockchain-based system:

- **Employers** register and pay premiums (3% of employee salary)
- **Employees** get registered with employment details and accrue benefit entitlements
- **Claims** are submitted by employees and approved/rejected by employers
- **Benefits** are withdrawn monthly by eligible unemployed workers

## Available Versions

### 🔷 UnemploymentVault (ETH)
- Native ETH-based implementation
- Salaries and benefits denominated in ETH
- Simple deployment for testing
- **File**: `src/UnemploymentVault.sol`

### 💵 UnemploymentVaultUSDC (USDC)
- ERC20 stablecoin implementation (USDC)
- Salaries and benefits in USD (6 decimals)
- Production-ready for real-world use
- **Files**: 
  - `src/UnemploymentVaultUSDC.sol` (main contract)
  - `src/MockUSDC.sol` (testing token)
  - `src/IERC20.sol` (minimal interface)
  - `src/ERC20.sol` (minimal implementation)

**Recommendation**: Use USDC version for production - no OpenZeppelin dependencies, stable value, familiar denominations.

## Contract Features

### ✅ Implemented
- Employer registration
- Employee registration (single and batch)
- Premium deposit system (3% of monthly salary to pooled fund)
- Employment termination by employer
- Claim submission by employee → PENDING status
- Employer approval (immediate) or rejection (within 30 days)
- Auto-approval after 30 days if employer doesn't respond
- Monthly benefit withdrawals with 30-day intervals (pull model)
- Benefit calculation: 70% of last salary
- Dynamic benefit duration based on employment length (3-24 months)
- **Both ETH and USDC versions available**

### 🚧 Future Enhancements
- Comprehensive test suite with edge cases
- Weighted average salary calculation (for varying salaries)
- Yield generation on pooled funds (integrate with Aave/Compound)
- Merkle trees for gas-efficient bulk operations
- Zero-knowledge proofs for salary privacy
- Multi-employer support per employee
- Dispute resolution mechanism
- Governance/admin controls
- Emergency pause functionality
- Re-employment support
- Parametric triggers (integration with oracles)

## Key Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| Premium Rate | 3% | Percentage of salary employers pay monthly |
| Minimum Employment | 12 months | Minimum duration to qualify for benefits |
| Benefit Percentage | 70% | Percentage of last salary paid as benefit |
| Min Benefit Duration | 3 months | Minimum benefit period (12 months employment) |
| Max Benefit Duration | 24 months | Maximum benefit period (10+ years employment) |
| Employer Response Period | 30 days | Time for employer to approve/reject claim |
| Withdrawal Interval | 30 days | Time between benefit withdrawals |

## Architecture

### Smart Contract Flow

```
1. Employer Registration → 2. Employee Registration → 3. Premium Deposits
                                                              ↓
                                                    4. Employment Period
                                                              ↓
                                          5. Employer Terminates Employment
                                                              ↓
                                           6. Employee Submits Claim (PENDING)
                                                              ↓
                                    ┌─────────────────────────┴──────────────┐
                                    ↓                                        ↓
                      7a. Employer Approves                    7b. No Response (30 days)
                          → APPROVED                                → Auto-Approve
                                    └─────────────────────────┬──────────────┘
                                                              ↓
                                           8. Employee Withdraws Benefits Monthly
                                                              ↓
                                                    9. Benefits Exhausted
                                                              ↓
                                                      Status: COMPLETED
```


## Benefit Calculation Formula

Benefits scale with employment duration:

```
if employment < 12 months:  Ineligible
if employment >= 12 months and < 24 months:  3 months benefit
if employment >= 24 months:  3 + ((employment - 12) / 12 × 2) months
Maximum cap: 24 months
```

**Examples:**
| Employment Duration | Benefit Duration |
|---------------------|------------------|
| 6 months | Not eligible |
| 12 months | 3 months |
| 24 months | 5 months |
| 36 months | 7 months |
| 60 months (5 years) | 11 months |
| 120+ months (10 years) | 24 months (capped) |

**Monthly Benefit Amount:** 70% of last monthly salary

## Prerequisites

Install Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## Setup

1. **Clone repository**:
```bash
git clone <your-repo-url>
cd InsuranceX
```

2. **Install dependencies**:
```bash
forge install
```

3. **Compile contracts**:
```bash
forge build
```

4. **Run tests** (coming soon):
```bash
forge test
```

## Deployment

### Local Development (Anvil)

**Terminal 1 - Start local blockchain:**
```bash
anvil
```

**Terminal 2 - Deploy ETH Version:**
```bash
forge script script/DeployVault.s.sol:DeployUnemploymentVault \
  --rpc-url http://localhost:8545 \
  --broadcast \
  -vv
```

**Terminal 2 - Deploy USDC Version:**
```bash
forge script script/DeployVaultUSDC.s.sol:DeployUnemploymentVaultUSDC \
  --rpc-url http://localhost:8545 \
  --broadcast \
  -vv
```

Both deployment scripts will:
1. Deploy the contract (and MockUSDC for USDC version)
2. Register 10 employers
3. Register 100 employees (10 per employer) using batch registration
4. Deposit initial premiums for all employees
5. Simulate a complete unemployment claim flow with withdrawals

**Expected output:**
- Contract address (and USDC address for USDC version)
- 10 registered employers
- 100 registered employees
- Total pooled funds from premiums
- Complete claim simulation (submit → approve → 3 withdrawals → completed)

### Arbitrum Sepolia (Testnet)

1. **Set environment variables**:
```bash
export PRIVATE_KEY=your_private_key_here
export ARBISCAN_API_KEY=your_arbiscan_api_key  # For contract verification
```

2. **Get testnet ETH**: 
   - Visit [Arbitrum Sepolia Faucet](https://faucet.quicknode.com/arbitrum/sepolia)

3. **Deploy ETH Version**:
```bash
forge script script/DeployVault.s.sol:DeployUnemploymentVault \
  --rpc-url https://sepolia-rollup.arbitrum.io/rpc \
  --broadcast \
  --verify \
  -vv
```

4. **Deploy USDC Version** (with real testnet USDC):
```bash
# Use real Arbitrum Sepolia USDC: 0x75faf114eafb1BDbe2F0316DF893fd58CE46AA4d
# Or deploy MockUSDC for testing

forge script script/DeployVaultUSDC.s.sol:DeployUnemploymentVaultUSDC \
  --rpc-url https://sepolia-rollup.arbitrum.io/rpc \
  --broadcast \
  --verify \
  -vv
```

### Arbitrum One (Mainnet)

⚠️ **NOT RECOMMENDED** - This is a POC and has not been audited!

**For USDC Version with Real USDC:**
- Arbitrum One USDC: `0xaf88d065e77c8cC2239327C5EDb3A432268e5831`

```bash
forge script script/DeployVaultUSDC.s.sol:DeployUnemploymentVaultUSDC \
  --rpc-url https://arb1.arbitrum.io/rpc \
  --broadcast \
  --verify \
  -vv
```

## Development Roadmap

### Phase 1: Core POC ✅
- [x] Basic contract structure
- [x] Employer and employee registration (batch support)
- [x] Premium deposits (ETH and USDC)
- [x] Claim submission and approval flow
- [x] Benefit withdrawals
- [x] Deployment scripts
- [x] Both ETH and USDC implementations

### Phase 2: Optimization & Testing 🚧
- [ ] Comprehensive unit tests
- [ ] Integration tests
- [ ] Gas optimization
- [ ] Edge case handling
- [ ] Re-employment support
- [ ] Error message improvements

### Phase 3: Scalability 📋
- [ ] Merkle tree implementation for bulk registration
- [ ] Off-chain data storage with on-chain verification
- [ ] Batch premium deposits
- [ ] Optimized storage patterns

### Phase 4: Privacy & Security 📋
- [ ] ZK-SNARK integration for salary privacy
- [ ] Encrypted data storage
- [ ] Security audit
- [ ] Access control improvements
- [ ] Emergency pause mechanism

### Phase 5: DeFi Integration 📋
- [ ] Yield generation on pooled funds (Aave/Compound)
- [ ] Multi-asset premium payments
- [ ] Liquidity management strategies
- [ ] Cross-chain support


## Known Limitations

⚠️ **This is a POC with known limitations:**

- **Not audited** - Do not use with real funds
- **Public salaries** - All data visible on-chain
- **No privacy** - Salary and employment details are transparent
- **Simplified model** - Real-world complexity not fully captured
- **Gas costs** - Not optimized for large-scale deployment
- **Single claim per employee** - Cannot handle re-employment scenarios yet
- **No dispute mechanism** - Rejected claims are final
- **No comprehensive tests** - Test coverage needed

## Security Considerations

### Implemented Protections
✅ Checks-Effects-Interactions pattern (prevents reentrancy)  
✅ Access controls (only employers can perform certain actions)  
✅ Time-based validation (30-day intervals for withdrawals)  
✅ State machine for claim status  
✅ Pool solvency checks before withdrawals  
✅ SafeERC20 for token transfers (USDC version)  

### Not Yet Implemented
❌ Comprehensive test coverage  
❌ External security audit  
❌ Formal verification  
❌ Upgradability pattern  
❌ Emergency pause mechanism  
❌ Rate limiting  
❌ Admin controls  

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request

## License

MIT License - see LICENSE file for details

## Disclaimer

This is experimental software provided as-is. It is a proof-of-concept for educational and testing purposes only. DO NOT use with real funds or in production environments without:
- Professional security audit
- Comprehensive testing
- Legal review
- Proper governance structure
- Risk management procedures

## Contact

For questions, issues, or contributions:
- Open an issue on GitHub
- Submit a pull request
- Reach out to the maintainers

---

**Built with ❤️ using Foundry**
