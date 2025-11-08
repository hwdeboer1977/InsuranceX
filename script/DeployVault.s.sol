// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/UnemploymentVault.sol";
import {console2 as console} from "forge-std/console2.sol";

/**
forge script script/DeployVault.s.sol:DeployUnemploymentVault --rpc-url http://localhost:8545 --broadcast -vv 2>&1 | grep -v "anvil-hardhat"
 */

// Deploys the contract
// Registers 10 employers
// Registers 100 employees (10 per employer)
// Deposits initial premiums

contract DeployUnemploymentVault is Script {
    UnemploymentVault public unemploymentVault;

    // 10 employers (Anvil default accounts 0..9)
    address[] public employers;
    uint256[] public employerPks;

    // 100 employees (10 per employer)
    address[] public employees;

    // Standard Anvil mnemonic
    string internal constant ANVIL_MNEMONIC =
        "test test test test test test test test test test test junk";

    function setUp() public {
        // allocate arrays with lengths 
        employers   = new address[](10);
        employerPks = new uint256[](10);
        employees   = new address[](100);

        // employers 0..9 (Anvil defaults)
        employers[0] = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
        employers[1] = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
        employers[2] = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
        employers[3] = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;
        employers[4] = 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65;
        employers[5] = 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc;
        employers[6] = 0x976EA74026E726554dB657fA54763abd0C3a0aa9;
        employers[7] = 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955;
        employers[8] = 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f;
        employers[9] = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720;

        // derive corresponding private keys from mnemonic
        for (uint32 i = 0; i < 10; i++) {
            employerPks[i] = vm.deriveKey(ANVIL_MNEMONIC, i);
        }

        // first 10 employee addresses (Anvil 10..19)
        employees[0] = 0xBcd4042DE499D14e55001CcbB24a551F3b954096;
        employees[1] = 0x71bE63f3384f5fb98995898A86B02Fb2426c5788;
        employees[2] = 0xFABB0ac9d68B0B445fB7357272Ff202C5651694a;
        employees[3] = 0x1CBd3b2770909D4e10f157cABC84C7264073C9Ec;
        employees[4] = 0xdF3e18d64BC6A983f673Ab319CCaE4f1a57C7097;
        employees[5] = 0xcd3B766CCDd6AE721141F452C550Ca635964ce71;
        employees[6] = 0x2546BcD3c84621e976D8185a91A922aE77ECEc30;
        employees[7] = 0xbDA5747bFD65F08deb54cb465eB87D40e51B197E;
        employees[8] = 0xdD2FD4581271e230360230F9337D5c0430Bf44C0;
        employees[9] = 0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199;

        // fill the rest with dummy EOAs
        for (uint160 i = 10; i < 100; i++) {
            employees[i] = address(uint160(0x1000000000000000000000000000000000000000) + i);
        }
    }

    function run() public {
        // 1) Deploy the contract with deployer key (account 0 by default)
        uint256 deployerPk = employerPks[0];
        vm.startBroadcast(deployerPk);
        console.log("Deploying UnemploymentVault...");
        unemploymentVault = new UnemploymentVault();
        console.log("UnemploymentVault deployed at:", address(unemploymentVault));
        vm.stopBroadcast();

        // 2) Register employers (each from its own wallet)
        console.log("\n=== Registering Employers ===");
        for (uint256 i = 0; i < employers.length; i++) {
            vm.startBroadcast(employerPks[i]);
            unemploymentVault.registerEmployer();
            console.log("Employer", i, "registered:", employers[i]);
            vm.stopBroadcast();
        }

        // 3) Batch-register 10 employees per employer
        console.log("\n=== Batch Registering Employees (10 per employer) ===");
        for (uint256 i = 0; i < employers.length; i++) {
            vm.startBroadcast(employerPks[i]);

        UnemploymentVault.EmployeeInit[] memory inits =
            new UnemploymentVault.EmployeeInit[](10);

            for (uint256 j = 0; j < 10; j++) {
                uint256 idx = i * 10 + j;
                uint256 salary =
                    3000 ether + (uint256(keccak256(abi.encodePacked(idx))) % 5000 ether);

                inits[j] = UnemploymentVault.EmployeeInit({
                    employee: employees[idx],
                    monthlySalary: salary
                });
            }

            unemploymentVault.registerEmployeesBatch(inits);

            console.log("Employer", i, "batch-registered 10 employees");
            vm.stopBroadcast();
        }

  

        // 4) Deposit initial premiums (3% of salary) — one tx per employee
        console.log("\n=== Depositing Initial Premiums ===");
        for (uint256 i = 0; i < employers.length; i++) {
            vm.startBroadcast(employerPks[i]);

            uint256 totalPremiumForEmployer;
            for (uint256 j = 0; j < 10; j++) {
                uint256 idx = i * 10 + j;

                (
                    address empEmployer,
                    address empEmployee,
                    , , // startDate, endDate
                    uint256 salary,
                    , , // totalPremiumsPaid, lastPremiumPaymentDate
                    bool isActive
                ) = unemploymentVault.employments(employers[i], employees[idx]);

                require(isActive && empEmployer == employers[i] && empEmployee == employees[idx], "bad employment");

                uint256 premium = (salary * 300) / 10000; // 3%
                unemploymentVault.depositPremium{value: premium}(employees[idx]);
                totalPremiumForEmployer += premium;
            }

            console.log("Employer", i,"deposited total premiums:", totalPremiumForEmployer / 1 ether);
            vm.stopBroadcast();
        }

        // 5) Summary
        console.log("\n=== Deployment Summary ===");
        console.log("Contract Address:", address(unemploymentVault));

        (uint256 employerCount, uint256 employeeCount, uint256 poolBalance) =
            unemploymentVault.getContractStats();
        console.log("Registered Employers:", employerCount);
        console.log("Registered Employees:", employeeCount);
        console.log("Total Pool Balance:", poolBalance / 1 ether, "ETH");
        console.log("\n=== Setup Complete ===");


    // Destruct employments   
    (
        address empEmployer,
        address empEmployee,
        uint256 startDate,
        uint256 endDate,
        uint256 monthlySalary,
        uint256 totalPremiumsPaid,
        uint256 lastPremiumPaymentDate,
        bool isActive
    ) = unemploymentVault.employments(employers[0], employees[0]);

    // Note: employer 0 has employees 0-9
    // and: employer 1 has employees 10-19 etc

    console.log("\n=== Sample Employment Record ===");
    console.log("Employer:", empEmployer);
    console.log("Employee:", empEmployee);
    console.log("Start Date:", startDate);
    console.log("End Date:", endDate);
    console.log("Monthly Salary:", monthlySalary / 1 ether, "ETH");
    console.log("Total Premiums Paid:", totalPremiumsPaid / 1 ether, "ETH");
    console.log("Last Premium Payment:", lastPremiumPaymentDate);
    console.log("Is Active:", isActive);

  // 6) Simulate an unemployment scenario
    console.log("\n=== Simulating Unemployment Claim ===");

    address testEmployee = employees[0];
    address testEmployer = employers[0];

    console.log("\n=== Fast-forwarding time by 13 months ===");
    vm.warp(block.timestamp + 395 days);
    console.log("Time advanced. Now employees have 13 months of employment");

    // Terminate employment
    vm.startBroadcast(employerPks[0]);
    unemploymentVault.terminateEmployment(testEmployee, block.timestamp);
    console.log("Employer 0 terminated employment for employee 0");
    vm.stopBroadcast();

    // Employee submits claim
    vm.startBroadcast(vm.deriveKey(ANVIL_MNEMONIC, 10));
    unemploymentVault.submitClaim(testEmployer, block.timestamp);
    console.log("Employee 0 submitted claim");
    vm.stopBroadcast();

    // Employer approves claim
    vm.startBroadcast(employerPks[0]);
    unemploymentVault.approveClaimByEmployer(testEmployee, block.timestamp);
    console.log("Employer 0 approved claim");
    vm.stopBroadcast();

    // NOW destruct the claim (after it's been created and approved)
    (
        address claimEmployee,
        address claimEmployer,
        uint256 applicationDate,
        uint256 employeeDeclaredEndDate,
        uint256 employerConfirmedEndDate,
        UnemploymentVault.ClaimStatus status,
        uint256 benefitDurationMonths,
        uint256 monthlyBenefitAmount,
        uint256 monthsWithdrawn,
        uint256 approvalTimestamp,
        uint256 lastWithdrawalTimestamp
    ) = unemploymentVault.claims(testEmployee);

    console.log("\n=== Final Claim Details ===");
    console.log("claimEmployee:", claimEmployee);
    console.log("claimEmployer:", claimEmployer);
    console.log("applicationDate:", applicationDate);
    console.log("employeeDeclaredEndDate:", employeeDeclaredEndDate);
    console.log("employerConfirmedEndDate:", employerConfirmedEndDate);
    console.log("status:", uint256(status)); // Should be 2 (APPROVED)
    console.log("benefitDurationMonths:", benefitDurationMonths);
    console.log("monthlyBenefitAmount:", monthlyBenefitAmount / 1 ether, "ETH");
    console.log("monthsWithdrawn:", monthsWithdrawn);
    console.log("approvalTimestamp:", approvalTimestamp);
    console.log("lastWithdrawalTimestamp:", lastWithdrawalTimestamp);

    // Test benefit withdrawals
    console.log("\n=== Testing Benefit Withdrawals ===");

    uint256 employeePk = vm.deriveKey(ANVIL_MNEMONIC, 10); // employee 0's key

    // Get initial balances
    uint256 employeeBalanceBefore = testEmployee.balance;
    (,, uint256 poolBefore) = unemploymentVault.getContractStats();
    console.log("Employee balance before:", employeeBalanceBefore / 1 ether, "ETH");
    console.log("Pool balance before:", poolBefore / 1 ether, "ETH");

    // Withdraw month 1
    vm.startBroadcast(employeePk);
    unemploymentVault.withdrawBenefit();
    vm.stopBroadcast();
    console.log("Withdrew month 1 benefit");

    // Check updated claim
    (,,,,,, , , uint256 withdrawn1, , ) = unemploymentVault.claims(testEmployee);
    console.log("Months withdrawn:", withdrawn1, "/ 3");

    // Fast-forward 30 days
    vm.warp(block.timestamp + 30 days);

    // Withdraw month 2
    vm.startBroadcast(employeePk);
    unemploymentVault.withdrawBenefit();
    vm.stopBroadcast();
    console.log("Withdrew month 2 benefit");

    (,,,,,, , , uint256 withdrawn2, , ) = unemploymentVault.claims(testEmployee);
    console.log("Months withdrawn:", withdrawn2, "/ 3");

    // Fast-forward 30 days
    vm.warp(block.timestamp + 30 days);

    // Withdraw month 3 (final)
    vm.startBroadcast(employeePk);
    unemploymentVault.withdrawBenefit();
    vm.stopBroadcast();
    console.log("Withdrew month 3 benefit (FINAL)");

    // Check final status
    (
        ,,,,,
        UnemploymentVault.ClaimStatus finalStatus,
        ,, 
        uint256 withdrawn3,
        ,
    ) = unemploymentVault.claims(testEmployee);

    console.log("Months withdrawn:", withdrawn3, "/ 3");
    console.log("Final claim status:", uint256(finalStatus), "(Should be 3 = COMPLETED)");

    // Final balances
    uint256 employeeBalanceAfter = testEmployee.balance;
    (,, uint256 poolAfter) = unemploymentVault.getContractStats();

    console.log("\n=== Final Balances ===");
    console.log("Employee balance after:", employeeBalanceAfter / 1 ether, "ETH");
    console.log("Employee gained:", (employeeBalanceAfter - employeeBalanceBefore) / 1 ether, "ETH");
    console.log("Expected gain:", (5222 * 3), "ETH");
    console.log("Pool balance after:", poolAfter / 1 ether, "ETH");
    console.log("Pool decreased by:", (poolBefore - poolAfter) / 1 ether, "ETH");

    console.log("Complete unemployment benefit cycle tested successfully!");
      
    }
}
