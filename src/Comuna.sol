// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract Comuna {
    // ========= Types =========
    enum LoanStatus {
        Pending,
        Rejected,
        Expired,
        Approved,
        Disbursed,
        Paid
    }

    struct Loan {
        address borrower;
        uint256 startPeriod;
        uint256 duration;
        uint256 amount;
        uint256 repaymentAmount;
        uint256 periodicPayment;
        uint256 balance;
        uint256 rejectionCount;
        uint256 approvalCount;
        LoanStatus status;
    }

    // ========= Events =========
    event Deposit(address indexed sender, uint256 indexed period, uint256 amount);
    event LoanRequest(address indexed borrower, uint256 indexed period, uint256 indexed loanId, uint256 amount);
    event LoanRequestVote(address indexed voter, uint256 indexed loanId, bool isApproved);
    event LoanApproved(uint256 indexed loanId, uint256 approvalCount, uint256 rejectionCount);
    event LoanRejected(uint256 indexed loanId, uint256 approvalCount, uint256 rejectionCount);
    event LoanDisbursed(uint256 indexed loanId);
    event LoanPayment(uint256 indexed loanId, uint256 amount);
    event LoanPaid(uint256 indexed loanId);

    // ========= State =========
    // Constants
    uint256 public immutable INITIAL_SHARE_PRICE;
    uint256 public immutable MULTIPLIER = 3; 
    uint256 public immutable INTEREST_RATE = 5; // 5%
    uint256 public immutable SERVICE_FEE = 20; // 20%
    uint256 public immutable PERIODS_PER_CYCLE = 12;
    uint256 public immutable PERID_DURATION = 30 days;

    // Token
    IERC20 public immutable token;

    // Governance
    address public chairman;

    // Cycle information
    uint256 public currentCycle = 1;
    uint256 public currentPeriod = 0;
    uint256 public nextPeriodStartTime = 0;
    bool public isCurrentPeriodActive = false;

    // Members
    address[] internal members;
    mapping(address => bool) internal isMember;

    // Funds
    uint256 public capitalDeposited;
    uint256 public capitalLoaned;
    uint256 public profit;

    // Shares
    uint256 public totalShares;
    mapping(address => uint256) internal sharesOwned;

    // Deposits
    mapping(uint256 => mapping(address => uint256)) internal deposits;
    mapping(uint256 => uint256) internal depositCount;
    mapping(address => uint256) internal depositBalance;

    // Loans
    Loan[] internal loans;
    mapping(uint256 => mapping(address => bool)) internal loanVoters;
    mapping(address => bool) internal hasLoan;

    // ========= Constructor =========
    constructor (address[] memory _initialMembers, address _chairman, address _token, uint256 _initialSharePrice) {
        INITIAL_SHARE_PRICE = _initialSharePrice;
        token = IERC20(_token);
        chairman = _chairman;


        bool isChairmanMember = false;
        for (uint i = 0; i < _initialMembers.length; i++) {
            members.push(_initialMembers[i]);
            isMember[_initialMembers[i]] = true;

            if (_initialMembers[i] == _chairman) {
                isChairmanMember = true;
            }
        }

        require(isChairmanMember, 'Chairman must be a member');
    }

    // ========= Modifiers =========
    modifier onlyMember() {
        require(isMember[msg.sender], "Not a member");
        _;
    }

    modifier onlyChairman {
        require(msg.sender == chairman);
        _;
    }

    // ========= Functions =========
    // Governance
    function startPeriod() public onlyChairman {
        require(isCurrentPeriodActive == false && block.timestamp >= nextPeriodStartTime, 'Period already active');
        
        currentPeriod++;
        isCurrentPeriodActive = true;
    }

    function endPeriod() public onlyChairman {
        require(isCurrentPeriodActive == true, 'Period already inactive');
        
        nextPeriodStartTime = block.timestamp + PERID_DURATION;
        isCurrentPeriodActive = false;

        for (uint i = 0; i < loans.length; i++) {
            Loan storage loan = loans[i];
            loan.status = LoanStatus.Expired;
        }
    }

    // Deposits
    function areDepositsOpen() public view returns(bool) {
        return isCurrentPeriodActive && depositCount[currentPeriod] < members.length;
    }

    function deposit(uint256 _amount) public onlyMember {
        require(areDepositsOpen(), "Deposits are not open");
        require(deposits[currentPeriod][msg.sender] == 0, 'Already deposited');
        require(_amount > 0, 'Amount must be greater than 0');

        depositCount[currentPeriod]++;
        deposits[currentPeriod][msg.sender] = _amount;
        depositBalance[msg.sender] += _amount;
        capitalDeposited += _amount;

        uint256 sharePrice = getSharePrice();
        uint256 shares = (_amount * 10000 ) / sharePrice;
        sharesOwned[msg.sender] += shares;

        bool success = token.transferFrom(msg.sender, address(this), _amount);
        require(success, 'Transfer failed');

        emit Deposit(msg.sender, currentPeriod, _amount);
    }

    // Loan Request
    function _calculatePeriodicPayment(uint256 _loanAmount, uint256 _loanDuration) internal pure returns (uint256) {
        // P = [r*PV] / [1 - (1 + r)^-N]
    
        // Convert the loan amount and annual interest rate to int128 format
        int128 loanAmount = ABDKMath64x64.fromUInt(_loanAmount);
        int128 interestRate = ABDKMath64x64.fromUInt(INTEREST_RATE);

        // Convert the annual interest rate to a monthly rate
        int128 monthlyRate = ABDKMath64x64.div(interestRate, ABDKMath64x64.fromUInt(12));

        // Calculate (1 + r)^N
        int128 onePlusRpowN = ABDKMath64x64.pow(ABDKMath64x64.add(ABDKMath64x64.fromUInt(1), monthlyRate), _loanDuration);

        // Calculate the denominator of the formula: 1 - (1 + r)^-N
        int128 denominator = ABDKMath64x64.sub(ABDKMath64x64.fromUInt(1), ABDKMath64x64.inv(onePlusRpowN));

        // Finally, calculate the monthly payment: P = r * PV / (1 - (1 + r) ^ -N)
        int128 monthlyPayment = ABDKMath64x64.div(ABDKMath64x64.mul(monthlyRate, loanAmount), denominator);

        // Return the monthly payment converted to uint256
        return uint256(ABDKMath64x64.toUInt(monthlyPayment));
    }

    function requestLoan(uint256 _amount, uint256 _duration) public onlyMember {
        require(isCurrentPeriodActive == true && depositCount[currentPeriod] == members.length, 'Loan requests are not open yet');
        require(_amount <= capitalDeposited, 'Amount not available');
        require(_amount * MULTIPLIER <= depositBalance[msg.sender], 'Amount above your limit');
        require(hasLoan[msg.sender] == false, 'Already has a loan');

        uint256 periodicPayment = _calculatePeriodicPayment(_amount, _duration);
        uint256 repaymentAmount = _amount + (periodicPayment * _duration);

        Loan memory newLoan = Loan({
            borrower: msg.sender,
            startPeriod: currentPeriod,
            duration: _duration,
            amount: _amount,
            repaymentAmount: repaymentAmount,
            balance: repaymentAmount,
            periodicPayment: periodicPayment,
            rejectionCount: 0,
            approvalCount: 0,
            status: LoanStatus.Pending
        });


        loans.push(newLoan);
        uint256 newLoanId = loans.length - 1;

        emit LoanRequest(msg.sender, currentPeriod, newLoanId, _amount);
    }

    function voteOnLoanRequest(uint256 _loanId, bool _isApproved) public onlyMember {
        require(loans[_loanId].status == LoanStatus.Pending, 'Request closed');
        require(loanVoters[_loanId][msg.sender] != true, 'Already voted');

        loanVoters[_loanId][msg.sender] = true;
        emit LoanRequestVote(msg.sender, _loanId, _isApproved);


        if (_isApproved) {
            _handleLoanApprovalVote(_loanId);
        } else {
            _handleLoanRejectionVote(_loanId);
        }
    }

    function _handleLoanApprovalVote(uint256 _loanId) internal {
        Loan storage loan = loans[_loanId];
        
        require(loan.amount <= capitalDeposited, 'Not enough funds');
        
        loan.approvalCount++;
        
        if (_isMajority(loan.approvalCount)) {
            capitalLoaned += loan.amount;
            capitalDeposited -= loan.amount;

            loan.status = LoanStatus.Approved;
            hasLoan[loan.borrower] = true;

            emit LoanApproved(_loanId, loan.approvalCount, loan.rejectionCount);
        }
    }

    function _handleLoanRejectionVote(uint256 _loanId) internal {
        Loan storage loan = loans[_loanId];
        loan.rejectionCount++;
        
        if (_isMajority(loan.rejectionCount)) {
            loan.status = LoanStatus.Rejected;
            emit LoanRejected(_loanId, loan.approvalCount, loan.rejectionCount);
        }
    }

    // Loan Disbursement
    function disburseLoan(uint256 _loanId) public onlyMember {
        Loan storage loan = loans[_loanId];
        require(loan.status == LoanStatus.Approved, 'Loan not approved');
        require(loan.borrower == msg.sender, 'Not the borrower');

        bool success = token.transfer(loan.borrower, loan.amount);
        require(success, 'Transfer failed');

        loan.status = LoanStatus.Disbursed;
        emit LoanDisbursed(_loanId);
    }

    // Loan Repayment
    function _calculateInterest(uint256 balance) internal pure returns (uint256) {
        return (balance * INTEREST_RATE) / (PERIODS_PER_CYCLE * 100);
    }

    function _calculatePrincipal(uint256 periodicPayment, uint256 interest) internal pure returns (uint256) {
        return periodicPayment - interest;
    }

    function makeLoanPayment(uint256 _loanId) public onlyMember {
        Loan storage loan = loans[_loanId];
        require(loan.status == LoanStatus.Disbursed, 'Loan not disbursed');
        require(loan.borrower == msg.sender, 'Not the borrower');

        uint256 interest = _calculateInterest(loan.balance);
        uint256 principal = _calculatePrincipal(loan.periodicPayment, interest);

        bool success = token.transferFrom(msg.sender, address(this), loan.periodicPayment);
        require(success, 'Transfer failed');

        loan.balance -= loan.periodicPayment;
        capitalLoaned -= principal;
        capitalDeposited += principal;
        profit += interest;

        emit LoanPayment(_loanId, loan.periodicPayment);

        if (loan.balance <= 0) {
            loan.status = LoanStatus.Paid;
            delete hasLoan[loan.borrower];
            emit LoanPaid(_loanId);
        }
    }

    // Distribute Profits

    // Helpers
    function _isMajority(uint256 _votes) internal view returns(bool) {
        return _votes > members.length / 2;
    }

    function getSharePrice() public view returns(uint256) {
        return INITIAL_SHARE_PRICE * ((1 + (INTEREST_RATE / 100 / PERIODS_PER_CYCLE)) ** currentCycle);
    }
}
