# InsuranceX - Unemployment Benefit Smart Contract

A proof-of-concept smart contract for managing unemployment benefits on Arbitrum, inspired by the Dutch unemployment insurance system.

⚠️ **WORK IN PROGRESS** - This is a POC for testing and learning purposes only.

## Overview

InsuranceX allows employers to pool premiums and provides unemployment benefits to eligible employees through a transparent, blockchain-based system:

- **Employers** register and pay premiums (3% of employee salary)
- **Employees** get registered with employment details and accrue benefit entitlements
- **Claims** are submitted by employees and approved/rejected by employers
- **Benefits** are withdrawn monthly by eligible unemployed workers

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

### 🚧 Future Enhancements
- Comprehensive test suite with edge cases
- ERC20 token support (USDC instead of ETH)
- Weighted average salary calculation (for varying salaries)
- Yield generation on pooled funds (integrate with Aave/Compound)
- Merkle trees for gas-efficient bulk operations
- Zero-knowledge proofs for salary privacy
- Multi-employer support per employee
- Dispute resolution mechanism
- Governance/admin controls
- Emergency pause functionality
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

### Data Structures

**Employment Record**
```solidity
struct Employment {
    address employer;
    address employee;
    uint256 startDate;
    uint256 endDate;              // 0 if still active
    uint256 currentMonthlySalary; // In wei
    uint256 totalPremiumsPaid;
    uint256 lastPremiumPaymentDate;
    bool isActive;
}
```

**Benefit Claim**
```solidity
struct Claim {
    address employee;
    address employer;
    uint256 applicationDate;
    uint256 employeeDeclaredEndDate;
    uint256 employerConfirmedEndDate;
    ClaimStatus status;           // NONE, PENDING, APPROVED, REJECTED, COMPLETED
    uint256 benefitDurationMonths;
    uint256 monthlyBenefitAmount;
    uint256 monthsWithdrawn;
    uint256 approvalTimestamp;
    uint256 lastWithdrawalTimestamp;
}
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

**Terminal 2 - Deploy contract:**
```bash
forge script script/DeployVault.s.sol:DeployUnemploymentVault \
  --rpc-url http://localhost:8545 \
  --broadcast \
  -vv
```

This deployment script will:
1. Deploy the UnemploymentVault contract
2. Register 10 employers
3. Register 100 employees (10 per employer) using batch registration
4. Deposit initial premiums for all employees
5. Simulate a complete unemployment claim flow with withdrawals

**Expected output:**
- Contract address
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

3. **Deploy**:
```bash
forge script script/DeployVault.s.sol:DeployUnemploymentVault \
  --rpc-url https://sepolia-rollup.arbitrum.io/rpc \
  --broadcast \
  --verify \
  -vv
```

### Arbitrum One (Mainnet)

⚠️ **NOT RECOMMENDED** - This is a POC and has not been audited!

```bash
forge script script/DeployVault.s.sol:DeployUnemploymentVault \
  --rpc-url https://arb1.arbitrum.io/rpc \
  --broadcast \
  --verify \
  -vv
```

## Interacting with the Contract

### View Functions (Cast)

**Check contract statistics:**
```bash
cast call <CONTRACT_ADDRESS> "getContractStats()" --rpc-url http://localhost:8545
# Returns: (employerCount, employeeCount, poolBalance)
```

**Check employment record:**
```bash
cast call <CONTRACT_ADDRESS> "getEmployment(address,address)" \
  <EMPLOYER_ADDRESS> \
  <EMPLOYEE_ADDRESS> \
  --rpc-url http://localhost:8545
```

**Check claim status:**
```bash
cast call <CONTRACT_ADDRESS> "getClaim(address)" \
  <EMPLOYEE_ADDRESS> \
  --rpc-url http://localhost:8545
```

**Calculate benefit duration:**
```bash
cast call <CONTRACT_ADDRESS> "calculateBenefitDuration(uint256)" 24 \
  --rpc-url http://localhost:8545
# Returns: 5 (months of benefits for 24 months employment)
```

### Write Functions (Cast)

**Register as employer:**
```bash
cast send <CONTRACT_ADDRESS> "registerEmployer()" \
  --private-key <YOUR_PRIVATE_KEY> \
  --rpc-url http://localhost:8545
```

**Register employee (as employer):**
```bash
cast send <CONTRACT_ADDRESS> "registerEmployee(address,uint256)" \
  <EMPLOYEE_ADDRESS> \
  5000000000000000000000 \
  --private-key <EMPLOYER_PRIVATE_KEY> \
  --rpc-url http://localhost:8545
# 5000 ETH monthly salary (in wei)
```

**Deposit premium (as employer):**
```bash
cast send <CONTRACT_ADDRESS> "depositPremium(address)" \
  <EMPLOYEE_ADDRESS> \
  --value 150000000000000000000 \
  --private-key <EMPLOYER_PRIVATE_KEY> \
  --rpc-url http://localhost:8545
# 150 ETH = 3% of 5000 ETH salary
```

## Testing Accounts (Anvil)

Anvil provides 10 pre-funded accounts. The deployment script uses:

| Account Index | Type | Address |
|--------------|------|---------|
| 0-9 | Employers | `0xf39Fd...` through `0xa0Ee7...` |
| 10-19 | Employees | `0xBcd40...` through `0x8626f...` |
| 20-109 | Employees | Derived addresses |

**Default Account 0:**
- Address: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
- Private Key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
- Balance: 10,000 ETH

## Development Roadmap

### Phase 1: Core POC ✅
- [x] Basic contract structure
- [x] Employer and employee registration
- [x] Premium deposits
- [x] Claim submission and approval flow
- [x] Benefit withdrawals
- [x] Deployment scripts

### Phase 2: Optimization & Testing 🚧
- [ ] Comprehensive unit tests
- [ ] Integration tests
- [ ] Gas optimization
- [ ] Edge case handling
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
- [ ] ERC20 token support (USDC/USDT)
- [ ] Multi-asset premium payments
- [ ] Liquidity management strategies

## Architecture Decisions

### Why Pooled Insurance Model?
All employer premiums go into a single pool, similar to real-world unemployment insurance. This provides:
- **Risk distribution** across all employers
- **Simplified accounting** and fund management
- **Scalability** for adding new participants
- **Realistic model** matching traditional systems

### Why Not ERC4626?
ERC4626 vaults are designed for situations where depositors = withdrawers. In this system:
- **Depositors** = Employers
- **Withdrawers** = Employees
- This asymmetry makes ERC4626 unsuitable
- Could integrate with ERC4626 vaults for yield generation later

### Scalability Strategy
For production with millions of employees:
- **On-chain**: Only commitments (Merkle roots), settlements, and disputes
- **Off-chain**: Detailed records, employment history, calculations
- **Proofs**: Merkle proofs for verification, ZK proofs for privacy
- **Cost**: O(1) on-chain storage instead of O(n)

## Known Limitations

⚠️ **This is a POC with known limitations:**

- **Not audited** - Do not use with real funds
- **Public salaries** - All data visible on-chain
- **No privacy** - Salary and employment details are transparent
- **Simplified model** - Real-world complexity not fully captured
- **Gas costs** - Not optimized for large-scale deployment
- **Single claim per employee** - Cannot handle re-employment scenarios yet
- **No dispute mechanism** - Rejected claims are final
- **ETH only** - No stablecoin support yet

## Security Considerations

### Implemented Protections
✅ Checks-Effects-Interactions pattern (prevents reentrancy)  
✅ Access controls (only employers can perform certain actions)  
✅ Time-based validation (30-day intervals for withdrawals)  
✅ State machine for claim status  
✅ Pool solvency checks before withdrawals  

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
