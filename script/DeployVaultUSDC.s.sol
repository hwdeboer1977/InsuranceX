// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/UnemploymentVaultUSDC.sol";
import "../src/MockUSDC.sol";
import { console2 } from "forge-std/console2.sol";

/**
forge script script/DeployVaultUSDC.s.sol:DeployUnemploymentVaultUSDC --rpc-url http://localhost:8545 --broadcast -vv --via-ir
 */
contract DeployUnemploymentVaultUSDC is Script {
    UnemploymentVault public unemploymentVault;
    MockUSDC public usdc;

    address[] public employers;
    uint256[] public employerPks;
    address[] public employees;

    string internal constant ANVIL_MNEMONIC =
        "test test test test test test test test test test test junk";

    // USDC has 6 decimals
    uint256 constant USDC_DECIMALS = 10**6;

    function setUp() public {
        employers   = new address[](10);
        employerPks = new uint256[](10);
        employees   = new address[](100);

        // Employers 0-9
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

        for (uint32 i = 0; i < 10; i++) {
            employerPks[i] = vm.deriveKey(ANVIL_MNEMONIC, i);
        }

        // Employees 0-9
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

        for (uint160 i = 10; i < 100; i++) {
            employees[i] = address(uint160(0x1000000000000000000000000000000000000000) + i);
        }
    }

    function run() public {
        uint256 deployerPk = employerPks[0];
        
        // 1) Deploy Mock USDC
        vm.startBroadcast(deployerPk);
        console.log("Deploying Mock USDC...");
        usdc = new MockUSDC();
        console.log("Mock USDC deployed at:", address(usdc));
        console.log("USDC Decimals:", usdc.decimals());
        
        // 2) Deploy UnemploymentVault with USDC address
        console.log("\nDeploying UnemploymentVault...");
        unemploymentVault = new UnemploymentVault(address(usdc));
        console.log("UnemploymentVault deployed at:", address(unemploymentVault));
        vm.stopBroadcast();

        // 3) Fund all employers with USDC
        console.log("\n=== Funding Employers with USDC ===");
        for (uint256 i = 0; i < employers.length; i++) {
            vm.startBroadcast(deployerPk);
            // Give each employer 100,000 USDC
            usdc.mint(employers[i], 100_000 * USDC_DECIMALS);
            console.log("Funded employer", i, "with 100,000 USDC");
            vm.stopBroadcast();
        }

        // 4) Register employers
        console.log("\n=== Registering Employers ===");
        for (uint256 i = 0; i < employers.length; i++) {
            vm.startBroadcast(employerPks[i]);
            unemploymentVault.registerEmployer();
            console.log("Employer", i, "registered");
            vm.stopBroadcast();
        }

        // 5) Batch register employees
        console.log("\n=== Batch Registering Employees ===");
        for (uint256 i = 0; i < employers.length; i++) {
            vm.startBroadcast(employerPks[i]);

            UnemploymentVault.EmployeeInit[] memory inits =
                new UnemploymentVault.EmployeeInit[](10);

            for (uint256 j = 0; j < 10; j++) {
                uint256 idx = i * 10 + j;
                // Salary between $3,000 and $8,000 per month
                uint256 baseSalary = 3000 * USDC_DECIMALS;
                uint256 variableSalary = (uint256(keccak256(abi.encodePacked(idx))) % 5000) * USDC_DECIMALS;
                uint256 salary = baseSalary + variableSalary;

                inits[j] = UnemploymentVault.EmployeeInit({
                    employee: employees[idx],
                    monthlySalary: salary
                });
            }

            unemploymentVault.registerEmployeesBatch(inits);
            console.log("Employer", i, "batch-registered 10 employees");
            vm.stopBroadcast();
        }

        // 6) Deposit premiums (requires USDC approval)
        console.log("\n=== Depositing Initial Premiums ===");
        for (uint256 i = 0; i < employers.length; i++) {
            vm.startBroadcast(employerPks[i]);

            uint256 totalPremiumForEmployer;
            for (uint256 j = 0; j < 10; j++) {
                uint256 idx = i * 10 + j;
                (,, , , uint256 salary, , , bool isActive) = 
                    unemploymentVault.employments(employers[i], employees[idx]);
                
                require(isActive, "Employment not active");
                
                uint256 premium = (salary * 300) / 10000; // 3%
                
                // Approve USDC spending
                usdc.approve(address(unemploymentVault), premium);
                
                // Deposit premium
                unemploymentVault.depositPremium(employees[idx]);
                totalPremiumForEmployer += premium;
            }

            console.log("Employer", i);
            console.log("Deposited premiums (USDC):", totalPremiumForEmployer / USDC_DECIMALS);
            vm.stopBroadcast();
        }

        // 7) Summary
        console.log("\n=== Deployment Summary ===");
        (uint256 employerCount, uint256 employeeCount, uint256 poolBalance) =
            unemploymentVault.getContractStats();
        console.log("USDC Address:", address(usdc));
        console.log("Contract Address:", address(unemploymentVault));
        console.log("Registered Employers:", employerCount);
        console.log("Registered Employees:", employeeCount);
        console.log("Total Pool Balance:", poolBalance / USDC_DECIMALS, "USDC");

        // 8) Show sample employment
        (
            address empEmployer,
            address empEmployee,
            uint256 startDate,
            uint256 endDate,
            uint256 monthlySalary,
            uint256 totalPremiumsPaid,
            ,
            bool isActive
        ) = unemploymentVault.employments(employers[0], employees[0]);

        console.log("\n=== Sample Employment Record ===");
        console.log("Employer:", empEmployer);
        console.log("Employee:", empEmployee);
        console.log("Monthly Salary:", monthlySalary / USDC_DECIMALS, "USDC");
        console.log("Total Premiums Paid:", totalPremiumsPaid / USDC_DECIMALS, "USDC");
        console.log("Is Active:", isActive);

        // 9) Simulate unemployment claim
        console.log("\n=== Simulating Unemployment Claim ===");
        
        address testEmployee = employees[0];
        address testEmployer = employers[0];
        uint256 employeePk = vm.deriveKey(ANVIL_MNEMONIC, 10);

        // Fast-forward 13 months
        console.log("Fast-forwarding time by 13 months...");
        vm.warp(block.timestamp + 395 days);
        
        uint256 duration = unemploymentVault.getEmploymentDurationMonths(testEmployer, testEmployee);
        console.log("Employment duration:", duration, "months");

        // Terminate employment
        vm.startBroadcast(employerPks[0]);
        unemploymentVault.terminateEmployment(testEmployee, block.timestamp);
        console.log("Employer terminated employment");
        vm.stopBroadcast();

        // Employee submits claim
        vm.startBroadcast(employeePk);
        unemploymentVault.submitClaim(testEmployer, block.timestamp);
        console.log("Employee submitted claim");
        vm.stopBroadcast();

        // Employer approves
        vm.startBroadcast(employerPks[0]);
        unemploymentVault.approveClaimByEmployer(testEmployee, block.timestamp);
        console.log("Employer approved claim");
        vm.stopBroadcast();

        // Check claim details
        (
            ,,,,,
            UnemploymentVault.ClaimStatus status,
            uint256 benefitDurationMonths,
            uint256 monthlyBenefitAmount,
            ,, 
        ) = unemploymentVault.claims(testEmployee);

        console.log("\n=== Claim Details ===");
        console.log("Status:", uint256(status), "(2 = APPROVED)");
        console.log("Benefit Duration:", benefitDurationMonths, "months");
        console.log("Monthly Benefit:", monthlyBenefitAmount / USDC_DECIMALS, "USDC");

        // 10) Test benefit withdrawals
        console.log("\n=== Testing Benefit Withdrawals ===");
        
        uint256 employeeBalanceBefore = usdc.balanceOf(testEmployee);
        (,, uint256 poolBefore) = unemploymentVault.getContractStats();
        console.log("Employee USDC balance before:", employeeBalanceBefore / USDC_DECIMALS);
        console.log("Pool balance before:", poolBefore / USDC_DECIMALS, "USDC");

        // Track time explicitly
        uint256 currentTime = block.timestamp;

        // === Month 1 ===
        vm.startBroadcast(employeePk);
        unemploymentVault.withdrawBenefit();
        vm.stopBroadcast();
        console.log("Withdrew month 1");

        (,,,,,, , , uint256 withdrawn1, , ) = unemploymentVault.claims(testEmployee);
        console.log("Months withdrawn:", withdrawn1, "/", benefitDurationMonths);

        // === Month 2 ===
        currentTime += 31 days;
        vm.warp(currentTime);

        vm.startBroadcast(employeePk);
        unemploymentVault.withdrawBenefit();
        vm.stopBroadcast();
        console.log("Withdrew month 2");

        (,,,,,, , , uint256 withdrawn2, , ) = unemploymentVault.claims(testEmployee);
        console.log("Months withdrawn:", withdrawn2, "/", benefitDurationMonths);

        // === Month 3 ===
        currentTime += 31 days;
        vm.warp(currentTime);

        vm.startBroadcast(employeePk);
        unemploymentVault.withdrawBenefit();
        vm.stopBroadcast();
        console.log("Withdrew month 3 (FINAL)");

        // Check final status
        (,,,,,UnemploymentVault.ClaimStatus finalStatus, , , uint256 monthsWithdrawn, , ) = 
            unemploymentVault.claims(testEmployee);

        console.log("\n=== Results ===");
        console.log("Months withdrawn:", monthsWithdrawn, "/", benefitDurationMonths);
        console.log("Final status:", uint256(finalStatus), "(3 = COMPLETED)");
        
        uint256 employeeBalanceAfter = usdc.balanceOf(testEmployee);
        console.log("Employee USDC balance after:", employeeBalanceAfter / USDC_DECIMALS);
        console.log("Employee gained:", (employeeBalanceAfter - employeeBalanceBefore) / USDC_DECIMALS, "USDC");
        
        (,, uint256 poolAfter) = unemploymentVault.getContractStats();
        console.log("Pool balance after:", poolAfter / USDC_DECIMALS, "USDC");
        console.log("Pool decreased by:", (poolBefore - poolAfter) / USDC_DECIMALS, "USDC");
        
        console.log("USDC-based unemployment benefit cycle completed successfully!");
    }
}
