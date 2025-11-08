// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title UnemploymentBenefit
 * @notice A smart contract for managing unemployment benefits based on employer premiums
 * @dev POC version - stores salary data publicly on-chain
 */

// Key features:
// Employee submits claim → Status: PENDING
// Employer has 30 days to either approve or reject
// If employer approves → Immediate approval
// If employer rejects within 30 days → Claim rejected
// If employer doesn't respond after 30 days → Employee can auto-approve
// Monthly benefit = 70% of last salary
// Withdrawals every 30 days

contract UnemploymentVault {
    
    // ============ State Variables ============
    
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
        uint256 currentMonthlySalary; // In wei
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
    event PremiumDeposited(address indexed employer, address indexed employee, uint256 amount, uint256 timestamp);
    event ClaimSubmitted(address indexed employee, address indexed employer, uint256 applicationDate);
    event ClaimApproved(address indexed employee, uint256 benefitDurationMonths, uint256 monthlyBenefitAmount);
    event ClaimRejected(address indexed employee, address indexed employer);
    event BenefitWithdrawn(address indexed employee, uint256 amount, uint256 monthNumber);
    event EmploymentTerminated(address indexed employer, address indexed employee, uint256 endDate);

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
    
    // ============ Modifiers ============
    
    modifier onlyRegisteredEmployer() {
        _onlyRegisteredEmployer();
        _;
    }

    function _onlyRegisteredEmployer() internal view {
        if (!isRegisteredEmployer[msg.sender]) revert EmployerNotRegistered();
    }
        
    // ============ Constructor ============
    
    constructor() {
        // Contract is ready to accept employer registrations
    }
    
    // ============ Employer Functions ============
    
    /**
     * @notice Register as an employer
     */
    function registerEmployer() external {
        if (isRegisteredEmployer[msg.sender]) revert EmployerAlreadyRegistered();
        
        isRegisteredEmployer[msg.sender] = true;
        registeredEmployerCount++;
        
        emit EmployerRegistered(msg.sender);
    }
    
    /**
     * @notice Register a new employee and start their employment
     * @param employee Address of the employee
     * @param monthlySalary Monthly salary in wei
     */
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

    /**
     * @notice Register multiple employees in a single transaction
     * @param inits Array of employee initialization data
     */
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
    
    /**
     * @notice Deposit premium for an employee
     * @param employee Address of the employee
     * @dev Premium is calculated as 3% of monthly salary and sent as msg.value
     */
    function depositPremium(address employee) 
        external 
        payable 
        onlyRegisteredEmployer 
    {
        Employment storage employment = employments[msg.sender][employee];
        
        if (!employment.isActive) revert EmploymentNotActive();
        
        uint256 expectedPremium = (employment.currentMonthlySalary * PREMIUM_RATE) / RATE_DENOMINATOR;
        
        if (msg.value != expectedPremium) revert InvalidPremiumAmount();
        
        employment.totalPremiumsPaid += msg.value;
        employment.lastPremiumPaymentDate = block.timestamp;
        
        totalPooledFunds += msg.value;
        
        emit PremiumDeposited(msg.sender, employee, msg.value, block.timestamp);
    }
    
    /**
     * @notice Update employee's salary
     * @param employee Address of the employee
     * @param newMonthlySalary New monthly salary amount
     */
    function updateEmployeeSalary(address employee, uint256 newMonthlySalary) 
        external 
        onlyRegisteredEmployer 
    {
        Employment storage employment = employments[msg.sender][employee];
        
        if (!employment.isActive) revert EmploymentNotActive();
        if (newMonthlySalary == 0) revert InvalidSalaryAmount();
        
        employment.currentMonthlySalary = newMonthlySalary;
    }

    // ============ Employee Claim Functions (Option C: Two-Step Approval) ============

    /**
     * @notice Submit unemployment benefit claim
     * @param employer Address of the employer
     * @param declaredEndDate Date when employment ended (as declared by employee)
     * @dev Creates a PENDING claim that requires employer approval within 30 days
     */
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

    /**
     * @notice Employer approves claim and confirms employment end date
     * @param employee Address of the employee
     * @param confirmedEndDate Confirmed end date by employer
     * @dev Immediately approves the claim
     */
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

    /**
     * @notice Employer rejects claim
     * @param employee Address of the employee
     * @dev Employer can reject within 30 days of claim submission
     */
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

    /**
    * @notice Terminate an employee's employment
    * @param employee Address of the employee
    * @param endDate Date when employment ended
    * @dev Employer must call this before employee can submit claim
    */
    function terminateEmployment(address employee, uint256 endDate) 
        external 
        onlyRegisteredEmployer 
    {
        Employment storage employment = employments[msg.sender][employee];
        
        if (!employment.isActive) revert EmploymentNotActive();
        if (endDate == 0) revert InvalidSalaryAmount(); // reuse error or create new one
        
        employment.isActive = false;
        employment.endDate = endDate;
        
        emit EmploymentTerminated(msg.sender, employee, endDate);
    }

    /**
     * @notice Auto-approve claim after 30-day waiting period if employer hasn't responded
     * @dev Can be called by employee after employer response period expires
     */
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

    /**
     * @notice Withdraw monthly benefit
     * @dev Employee can withdraw one month's benefit at a time, with 30-day intervals
     */
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
        
        (bool success, ) = payable(msg.sender).call{value: claim.monthlyBenefitAmount}("");
        require(success, "Transfer failed");
        
        emit BenefitWithdrawn(msg.sender, claim.monthlyBenefitAmount, claim.monthsWithdrawn);
    }
        
    // ============ View Functions ============
    
    /**
     * @notice Get employment details
     * @param employer Address of the employer
     * @param employee Address of the employee
     * @return Employment struct
     */
    function getEmployment(address employer, address employee) 
        external 
        view 
        returns (Employment memory) 
    {
        return employments[employer][employee];
    }
    
    /**
     * @notice Get claim details for an employee
     * @param employee Address of the employee
     * @return Claim struct
     */
    function getClaim(address employee) 
        external 
        view 
        returns (Claim memory) 
    {
        return claims[employee];
    }
    
    /**
     * @notice Calculate employment duration in months
     * @param employer Address of the employer
     * @param employee Address of the employee
     * @return months Number of months employed
     */
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
    
    /**
     * @notice Calculate benefit duration based on employment length
     * @param employmentMonths Number of months employed
     * @return benefitMonths Number of months of benefits entitled
     */
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
    
    /**
     * @notice Get contract stats
     * @return employerCount Number of registered employers
     * @return employeeCount Number of registered employees
     * @return poolBalance Total pooled funds
     */
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
