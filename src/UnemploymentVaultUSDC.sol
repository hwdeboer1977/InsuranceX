// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./IERC20.sol";

/**
 * @title UnemploymentVault
 * @notice A smart contract for managing unemployment benefits using USDC
 * @dev POC version - stores salary data publicly on-chain
 */
contract UnemploymentVault {
    using SafeERC20 for IERC20;
    
    // ============ State Variables ============
    
    /// @notice USDC token contract
    IERC20 public immutable usdc;
    
    /// @notice Premium rate that employers pay (3% = 300 basis points)
    uint256 public constant PREMIUM_RATE = 300; // 3.00%
    uint256 public constant RATE_DENOMINATOR = 10000; // For basis points calculation
    
    /// @notice Minimum employment duration to qualify (12 months)
    uint256 public constant MIN_EMPLOYMENT_MONTHS = 12;
    
    /// @notice Benefit percentage of average salary (70%)
    uint256 public constant BENEFIT_PERCENTAGE = 70;
    uint256 public constant BENEFIT_DENOMINATOR = 100;
    
    /// @notice Employer response period (30 days)
    uint256 public constant EMPLOYER_RESPONSE_PERIOD = 30 days;
    
    /// @notice Withdrawal interval (30 days between withdrawals)
    uint256 public constant WITHDRAWAL_INTERVAL = 30 days;
    
    /// @notice Total pooled funds from all employers
    uint256 public totalPooledFunds;
    
    // ============ Structs ============
    
    /// @notice Employment record tracking
    struct Employment {
        address employer;
        address employee;
        uint256 startDate;
        uint256 endDate; // 0 if still active
        uint256 currentMonthlySalary; // In USDC (6 decimals)
        uint256 totalPremiumsPaid;
        uint256 lastPremiumPaymentDate;
        bool isActive;
    }

    /// @notice Struct for batch employee registration
    struct EmployeeInit {
        address employee;
        uint256 monthlySalary;  
    }
        
    /// @notice Benefit claim tracking
    enum ClaimStatus {
        NONE,
        PENDING,
        APPROVED,
        REJECTED,
        COMPLETED
    }
    
    struct Claim {
        address employee;
        address employer;
        uint256 applicationDate;
        uint256 employeeDeclaredEndDate;
        uint256 employerConfirmedEndDate;
        ClaimStatus status;
        uint256 benefitDurationMonths;
        uint256 monthlyBenefitAmount;
        uint256 monthsWithdrawn;
        uint256 approvalTimestamp;
        uint256 lastWithdrawalTimestamp;
    }
    
    // ============ Storage Mappings ============
    
    /// @notice Mapping from employer to employee to employment record
    mapping(address => mapping(address => Employment)) public employments;
    
    /// @notice Mapping from employee to their active claim
    mapping(address => Claim) public claims;
    
    /// @notice Track registered employers
    mapping(address => bool) public isRegisteredEmployer;
    
    /// @notice Track registered employees
    mapping(address => bool) public isRegisteredEmployee;
    
    /// @notice Count of registered employers and employees
    uint256 public registeredEmployerCount;
    uint256 public registeredEmployeeCount;
    
    // ============ Events ============
    
    event EmployerRegistered(address indexed employer);
    event EmployeeRegistered(address indexed employer, address indexed employee, uint256 startDate, uint256 monthlySalary);
    event EmploymentTerminated(address indexed employer, address indexed employee, uint256 endDate);
    event PremiumDeposited(address indexed employer, address indexed employee, uint256 amount, uint256 timestamp);
    event ClaimSubmitted(address indexed employee, address indexed employer, uint256 applicationDate);
    event ClaimApproved(address indexed employee, uint256 benefitDurationMonths, uint256 monthlyBenefitAmount);
    event ClaimRejected(address indexed employee, address indexed employer);
    event BenefitWithdrawn(address indexed employee, uint256 amount, uint256 monthNumber);
    
    // ============ Errors ============
    
    error EmployerAlreadyRegistered();
    error EmployerNotRegistered();
    error EmployeeAlreadyRegistered();
    error EmployeeNotRegistered();
    error EmploymentAlreadyExists();
    error EmploymentNotFound();
    error EmploymentNotActive();
    error EmploymentStillActive();
    error InvalidSalaryAmount();
    error InvalidPremiumAmount();
    error ClaimAlreadyExists();
    error ClaimNotFound();
    error ClaimNotPending();
    error ClaimNotApproved();
    error InsufficientEmploymentDuration();
    error ConfirmationPeriodNotExpired();
    error ResponsePeriodExpired();
    error NotAuthorized();
    error WithdrawalTooSoon();
    error AllBenefitsWithdrawn();
    error InsufficientPoolFunds();
    error ZeroAddress();
    
    // ============ Modifiers ============
    
    modifier onlyRegisteredEmployer() {
        _onlyRegisteredEmployer();
        _;
    }

    function _onlyRegisteredEmployer() internal view {
        if (!isRegisteredEmployer[msg.sender]) revert EmployerNotRegistered();
    }
        
    // ============ Constructor ============
    
    constructor(address _usdc) {
        if (_usdc == address(0)) revert ZeroAddress();
        usdc = IERC20(_usdc);
    }
    
    // ============ Employer Functions ============
    
    function registerEmployer() external {
        if (isRegisteredEmployer[msg.sender]) revert EmployerAlreadyRegistered();
        
        isRegisteredEmployer[msg.sender] = true;
        registeredEmployerCount++;
        
        emit EmployerRegistered(msg.sender);
    }
    
    function registerEmployee(address employee, uint256 monthlySalary) 
        external 
        onlyRegisteredEmployer 
    {
        if (monthlySalary == 0) revert InvalidSalaryAmount();
        if (employments[msg.sender][employee].isActive) revert EmploymentAlreadyExists();
        
        employments[msg.sender][employee] = Employment({
            employer: msg.sender,
            employee: employee,
            startDate: block.timestamp,
            endDate: 0,
            currentMonthlySalary: monthlySalary,
            totalPremiumsPaid: 0,
            lastPremiumPaymentDate: block.timestamp,
            isActive: true
        });
        
        if (!isRegisteredEmployee[employee]) {
            isRegisteredEmployee[employee] = true;
            registeredEmployeeCount++;
        }
        
        emit EmployeeRegistered(msg.sender, employee, block.timestamp, monthlySalary);
    }

    function registerEmployeesBatch(EmployeeInit[] calldata inits)
        external
        onlyRegisteredEmployer
    {
        uint256 n = inits.length;
        for (uint256 i; i < n; ++i) {
            address e = inits[i].employee;
            uint256 s = inits[i].monthlySalary;
            
            if (s == 0) revert InvalidSalaryAmount();
            if (employments[msg.sender][e].isActive) revert EmploymentAlreadyExists();

            employments[msg.sender][e] = Employment({
                employer: msg.sender,
                employee: e,
                startDate: block.timestamp,
                endDate: 0,
                currentMonthlySalary: s,
                totalPremiumsPaid: 0,
                lastPremiumPaymentDate: block.timestamp,
                isActive: true
            });

            if (!isRegisteredEmployee[e]) {
                isRegisteredEmployee[e] = true;
                registeredEmployeeCount++;
            }

            emit EmployeeRegistered(msg.sender, e, block.timestamp, s);
        }
    }
    
    function depositPremium(address employee) 
        external 
        onlyRegisteredEmployer 
    {
        Employment storage employment = employments[msg.sender][employee];
        
        if (!employment.isActive) revert EmploymentNotActive();
        
        uint256 expectedPremium = (employment.currentMonthlySalary * PREMIUM_RATE) / RATE_DENOMINATOR;
        
        usdc.safeTransferFrom(msg.sender, address(this), expectedPremium);
        
        employment.totalPremiumsPaid += expectedPremium;
        employment.lastPremiumPaymentDate = block.timestamp;
        
        totalPooledFunds += expectedPremium;
        
        emit PremiumDeposited(msg.sender, employee, expectedPremium, block.timestamp);
    }
    
    function updateEmployeeSalary(address employee, uint256 newMonthlySalary) 
        external 
        onlyRegisteredEmployer 
    {
        Employment storage employment = employments[msg.sender][employee];
        
        if (!employment.isActive) revert EmploymentNotActive();
        if (newMonthlySalary == 0) revert InvalidSalaryAmount();
        
        employment.currentMonthlySalary = newMonthlySalary;
    }

    function terminateEmployment(address employee, uint256 endDate) 
        external 
        onlyRegisteredEmployer 
    {
        Employment storage employment = employments[msg.sender][employee];
        
        if (!employment.isActive) revert EmploymentNotActive();
        if (endDate == 0) revert InvalidSalaryAmount();
        
        employment.isActive = false;
        employment.endDate = endDate;
        
        emit EmploymentTerminated(msg.sender, employee, endDate);
    }

    // ============ Employee Claim Functions ============

    function submitClaim(address employer, uint256 declaredEndDate) 
        external 
    {
        Employment storage employment = employments[employer][msg.sender];
        
        if (employment.startDate == 0) revert EmploymentNotFound();
        if (employment.isActive) revert EmploymentStillActive();
        if (claims[msg.sender].status != ClaimStatus.NONE) revert ClaimAlreadyExists();
        
        uint256 employmentMonths = getEmploymentDurationMonths(employer, msg.sender);
        if (employmentMonths < MIN_EMPLOYMENT_MONTHS) revert InsufficientEmploymentDuration();
        
        uint256 benefitDuration = calculateBenefitDuration(employmentMonths);
        uint256 monthlyBenefit = (employment.currentMonthlySalary * BENEFIT_PERCENTAGE) / BENEFIT_DENOMINATOR;
        
        claims[msg.sender] = Claim({
            employee: msg.sender,
            employer: employer,
            applicationDate: block.timestamp,
            employeeDeclaredEndDate: declaredEndDate,
            employerConfirmedEndDate: 0,
            status: ClaimStatus.PENDING,
            benefitDurationMonths: benefitDuration,
            monthlyBenefitAmount: monthlyBenefit,
            monthsWithdrawn: 0,
            approvalTimestamp: 0,
            lastWithdrawalTimestamp: 0
        });
        
        emit ClaimSubmitted(msg.sender, employer, block.timestamp);
    }

    function approveClaimByEmployer(address employee, uint256 confirmedEndDate) 
        external 
        onlyRegisteredEmployer 
    {
        Employment storage employment = employments[msg.sender][employee];
        Claim storage claim = claims[employee];
        
        if (claim.status != ClaimStatus.PENDING) revert ClaimNotPending();
        if (claim.employer != msg.sender) revert NotAuthorized();
        
        employment.endDate = confirmedEndDate;
        employment.isActive = false;
        
        claim.employerConfirmedEndDate = confirmedEndDate;
        claim.status = ClaimStatus.APPROVED;
        claim.approvalTimestamp = block.timestamp;
        
        emit ClaimApproved(employee, claim.benefitDurationMonths, claim.monthlyBenefitAmount);
    }

    function rejectClaimByEmployer(address employee) 
        external 
        onlyRegisteredEmployer 
    {
        Claim storage claim = claims[employee];
        
        if (claim.status != ClaimStatus.PENDING) revert ClaimNotPending();
        if (claim.employer != msg.sender) revert NotAuthorized();
        
        if (block.timestamp >= claim.applicationDate + EMPLOYER_RESPONSE_PERIOD) {
            revert ResponsePeriodExpired();
        }
        
        claim.status = ClaimStatus.REJECTED;
        
        emit ClaimRejected(employee, msg.sender);
    }

    function autoApproveClaim() external {
        Claim storage claim = claims[msg.sender];
        Employment storage employment = employments[claim.employer][msg.sender];
        
        if (claim.status != ClaimStatus.PENDING) revert ClaimNotPending();
        
        if (block.timestamp < claim.applicationDate + EMPLOYER_RESPONSE_PERIOD) {
            revert ConfirmationPeriodNotExpired();
        }
        
        claim.status = ClaimStatus.APPROVED;
        claim.approvalTimestamp = block.timestamp;
        
        employment.endDate = claim.employeeDeclaredEndDate;
        employment.isActive = false;
        
        emit ClaimApproved(msg.sender, claim.benefitDurationMonths, claim.monthlyBenefitAmount);
    }

    function withdrawBenefit() external {
        Claim storage claim = claims[msg.sender];
        
        if (claim.status != ClaimStatus.APPROVED) revert ClaimNotApproved();
        if (claim.monthsWithdrawn >= claim.benefitDurationMonths) revert AllBenefitsWithdrawn();
        
        if (claim.lastWithdrawalTimestamp > 0 && 
            block.timestamp < claim.lastWithdrawalTimestamp + WITHDRAWAL_INTERVAL) {
            revert WithdrawalTooSoon();
        }
        
        if (totalPooledFunds < claim.monthlyBenefitAmount) revert InsufficientPoolFunds();
        
        claim.monthsWithdrawn++;
        claim.lastWithdrawalTimestamp = block.timestamp;
        totalPooledFunds -= claim.monthlyBenefitAmount;
        
        if (claim.monthsWithdrawn >= claim.benefitDurationMonths) {
            claim.status = ClaimStatus.COMPLETED;
        }
        
        usdc.safeTransfer(msg.sender, claim.monthlyBenefitAmount);
        
        emit BenefitWithdrawn(msg.sender, claim.monthlyBenefitAmount, claim.monthsWithdrawn);
    }
        
    // ============ View Functions ============
    
    function getEmployment(address employer, address employee) 
        external 
        view 
        returns (Employment memory) 
    {
        return employments[employer][employee];
    }
    
    function getClaim(address employee) 
        external 
        view 
        returns (Claim memory) 
    {
        return claims[employee];
    }
    
    function getEmploymentDurationMonths(address employer, address employee) 
        public 
        view 
        returns (uint256 months) 
    {
        Employment memory employment = employments[employer][employee];
        if (employment.startDate == 0) return 0;
        
        uint256 endTime = employment.endDate > 0 ? employment.endDate : block.timestamp;
        uint256 durationSeconds = endTime - employment.startDate;
        
        months = durationSeconds / 30 days;
    }
    
    function calculateBenefitDuration(uint256 employmentMonths) 
        public 
        pure 
        returns (uint256 benefitMonths) 
    {
        if (employmentMonths < MIN_EMPLOYMENT_MONTHS) {
            return 0;
        }
        
        if (employmentMonths < 24) {
            return 3;
        }
        
        benefitMonths = 3 + (((employmentMonths - 12) * 2) / 12);
        
        if (benefitMonths > 24) {
            benefitMonths = 24;
        }
    }
    
    function getContractStats() 
        external  
        view 
        returns (
            uint256 employerCount,
            uint256 employeeCount,
            uint256 poolBalance
        ) 
    {
        return (
            registeredEmployerCount,
            registeredEmployeeCount,
            totalPooledFunds
        );
    }
}
