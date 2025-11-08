# Unemployment Benefit Smart Contract

A proof-of-concept smart contract for managing unemployment benefits on Arbitrum, inspired by the Dutch unemployment insurance system.

STILL WORK IN PROGRESS!!

## Overview

This contract allows:
- Employers to register and pay premiums (3% of employee salary)
- Employees to be registered with their employment details
- Benefit calculations based on employment duration (3-24 months)
- Claims submission, employer confirmation, and benefit withdrawals
- Use Merkle proofs and ZK proofs

## Contract Features

### Current Implementation
- ✅ Employer & employee registration (including batch registration!)
- ✅ Premium deposits (3% of salary)
- ✅ Employee submits claim → PENDING status
- ✅ Employer can approve (immediate) or reject (within 30 days)
- ✅ Auto-approve after 30 days if employer doesn't respond
- ✅ Monthly benefit withdrawals (30-day intervals)
- ✅ 70% of last salary as benefit
- ✅ Benefit duration based on employment length


### Key Parameters
- **Premium Rate**: 3% of monthly salary
- **Minimum Employment**: 12 months to qualify
- **Benefit Percentage**: 70% of average salary
- **Benefit Duration**: 3-24 months based on employment length
- **Confirmation Timeout**: 30 days for employer response

## Prerequisites

Install Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## Setup

1. **Install dependencies**:
```bash
forge install
```

2. **Compile contracts**:
```bash
forge build
```

3. **Run tests** (when tests are added):
```bash
forge test
```

## Deployment

### Local Deployment (Anvil)

1. **Start Anvil** (local testnet):
```bash
anvil
```

2. **Deploy the contract** in a new terminal:
```bash
forge script script/Deploy.s.sol:DeployUnemploymentBenefit --rpc-url http://localhost:8545 --broadcast -vvvv
```

This will:
- Deploy the UnemploymentBenefit contract
- Register 10 employers
- Register 100 employees (10 per employer)
- Deposit initial premiums for all employees

### Arbitrum Sepolia Deployment (Testnet)

1. **Set environment variables**:
```bash
export PRIVATE_KEY=your_private_key_here
export ARBISCAN_API_KEY=your_arbiscan_api_key
```

2. **Deploy**:
```bash
forge script script/Deploy.s.sol:DeployUnemploymentBenefit \
  --rpc-url arbitrum_sepolia \
  --broadcast \
  --verify \
  -vvvv
```

### Arbitrum One Deployment (Mainnet)

```bash
forge script script/Deploy.s.sol:DeployUnemploymentBenefit \
  --rpc-url arbitrum \
  --broadcast \
  --verify \
  -vvvv
```

## Interacting with the Contract

### Using Cast (Foundry CLI)

**Get contract stats**:
```bash
cast call <CONTRACT_ADDRESS> "getContractStats()" --rpc-url http://localhost:8545
```

**Check employment details**:
```bash
cast call <CONTRACT_ADDRESS> "getEmployment(address,address)" <EMPLOYER_ADDRESS> <EMPLOYEE_ADDRESS> --rpc-url http://localhost:8545
```

**Calculate benefit duration**:
```bash
cast call <CONTRACT_ADDRESS> "calculateBenefitDuration(uint256)" 24 --rpc-url http://localhost:8545
```

### Using Forge Console

```bash
forge console --rpc-url http://localhost:8545
```

Then in the console:
```javascript
UnemploymentBenefit ub = UnemploymentBenefit(<CONTRACT_ADDRESS>);
ub.getContractStats();
```

## Contract Architecture

### Data Structures

**Employment**:
- employer: address
- employee: address
- startDate: timestamp
- endDate: timestamp (0 if active)
- currentMonthlySalary: uint256
- totalPremiumsPaid: uint256
- lastPremiumPaymentDate: timestamp
- isActive: bool

**Claim** (structure ready for implementation):
- employee: address
- employer: address
- applicationDate: timestamp
- employeeDeclaredEndDate: timestamp
- employerConfirmedEndDate: timestamp
- status: enum (PENDING, APPROVED, REJECTED, COMPLETED)
- benefitDurationMonths: uint256
- monthlyBenefitAmount: uint256
- monthsWithdrawn: uint256
- approvalTimestamp: timestamp
- lastWithdrawalTimestamp: timestamp

## Benefit Calculation Formula

```
if employmentMonths < 12: Not eligible
if employmentMonths >= 12 and < 24: 3 months benefit
if employmentMonths >= 24: 3 + ((employmentMonths - 12) / 12 * 2) months
Maximum: 24 months
```

**Examples**:
- 12 months worked → 3 months benefit
- 24 months worked → 5 months benefit
- 60 months worked → 11 months benefit
- 120+ months worked → 24 months benefit (capped)

## Testing with Anvil Accounts

Anvil provides 10 default funded accounts. The deployment script uses:
- **Accounts 0-9**: Employers (10 employers)
- **Accounts 10-109**: Employees (100 employees, 10 per employer)

Default Anvil account 0:
- Address: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
- Private Key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`

## Future Enhancements

### Coming Soon
- [ ] Employee claim submission
- [ ] Employer confirmation/rejection flow
- [ ] 7-day auto-approval timeout
- [ ] Monthly benefit withdrawal (pull model)
- [ ] Comprehensive test suite

### Future Considerations
- [ ] ERC20 token support (USDC instead of ETH)
- [ ] Weighted average salary calculation
- [ ] Yield generation on pooled funds
- [ ] Zero-knowledge proofs for privacy
- [ ] Multi-employer support per employee
- [ ] Governance/admin controls
- [ ] Emergency pause functionality

## Security Considerations

⚠️ **This is a POC (Proof of Concept)**:
- Not audited
- Uses simplified assumptions
- Salaries are public on-chain
- No privacy features
- Limited access controls

Do NOT use in production without:
- Professional security audit
- Comprehensive testing
- Privacy enhancements
- Proper governance

## License

MIT

## Contact

For questions or contributions, please open an issue or submit a pull request.