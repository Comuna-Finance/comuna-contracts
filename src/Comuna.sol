// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Comuna {
    // ========= Types =========
    enum LoanStatus {
        Pending,
        Rejected,
        Expired,
        Approved,
        Claimed,
        Paid
    }

    struct Loan {
        address borrower;
        uint256 startPeriod;
        uint256 periods;
        uint256 amountBorrowed;
        uint256 amountOwed;
        uint256 amountPaid;
        uint256 interest;
        uint256 rejectionCount;
        uint256 approvalCount;
        LoanStatus status;
    }

    // ========= Events =========
    event Deposit(address indexed sender, uint256 period, uint256 amount);
    event LoanRequest(address indexed borrower, uint256 indexed loanId, uint256 amount, uint256 periods);
    event LoanRequestVote(address indexed voter, uint256 indexed loanId, bool isApproved);
    event LoanApproved(uint256 indexed loanId, uint256 approvalCount, uint256 rejectionCount);
    event LoanRejected(uint256 indexed loanId, uint256 approvalCount, uint256 rejectionCount);

    // ========= State =========
    // Constants
    address public immutable TOKEN;
    uint256 public immutable MULTIPLIER = 3; 
    uint256 public immutable INTEREST_RATE = 0.05;
    uint256 public immutable PERIODS_PER_CYCLE = 12;
    uint256 public immutable PERID_DURATION = 30 days;

    // Governance
    address public chairman;

    // Cycle information
    uint256 public currentCycle = 1;
    uint256 public currentPeriod = 0;
    uint256 public nextPeriodStartTime = 0;
    bool public isCurrentPeriodActive = false;

    // Funds
    uint256 public interestEarned;
    uint256 public amountDeposited;
    uint256 public amountApproved;
    uint256 public amountInvested;

    // Members
    address[] internal members;
    mapping(address => bool) internal isMember;

    // Deposits
    mapping(uint256 => mapping(address => uint256)) internal deposits;
    mapping(uint256 => uint256) internal depositCount;
    mapping(address => uint256) internal depositBalance;

    // Loans
    Loan[] internal loans;
    mapping(uint256 => mapping(address => bool)) internal loanVoters;

    // ========= Functions =========
    constructor (address[] memory _initialMembers, address _chairman, address _token) {
        TOKEN = _token;

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

    modifier onlyMember() {
        require(isMember[msg.sender], "Not a member");
        _;
    }

    modifier onlyChairman {
        require(msg.sender == chairman);
        _;
    }

    // ======= PERIOD CONTROL =======
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
            loan.status = LoanStatus.Expireds;
        }
    }

    // ======= DEPOSITS =======
    function areDepositsOpen() public view returns(bool) {
        return isCurrentPeriodActive && depositCount[currentPeriod] < members.length;
    }

    function deposit(uint256 _amount) public onlyMember {
        require(areDepositsOpen(), "Deposits are not open");
        require(deposits[currentPeriod][msg.sender] == 0, 'Already deposited');

        deposits[currentPeriod][msg.sender] = _amount;
        depositBalance[msg.sender] += _amount;
        depositCount[currentPeriod]++;

        // token.safeTransferFrom(msg.sender, address(this), _amount); // todo: implement ERC20
        emit Deposit(msg.sender, currentPeriod, _amount);
    }

    // ======= LOANS =======
    function requestLoan(uint256 _amount, uint256 _periods) public onlyMember {
        require(isCurrentPeriodActive == true && depositCount[currentPeriod] == members.length, 'Loan requests are not open yet');
        require(_amount <= amountDeposited, 'Amount not available');
        require(_amount * MULTIPLIER <= depositBalance[msg.sender], 'Amount above your limit');

        // todo: create
        Loan memory newLoan = Loan({
            borrower: msg.sender,
            startPeriod: currentPeriod,
            periods: _periods,
            amount: _amount,
            repaymentAmount,
            interestRate,
            amountPaid,
            rejectionCount: 0,
            approvalCount: 0,
            status: LoanStatus.Pending
        });


        loans.push(newLoan);
        uint256 newLoanId = loans.length - 1;

        emit LoanRequest(msg.sender, newLoanId, _amount, _periods);
    }

    function voteOnLoanRequest(uint256 _loanId, bool _isApproved) public onlyMember {
        require(loans[_loanId].status == LoanStatus.Pending, 'Request closed');
        require(loanVoters[_loanId][msg.sender] != true, 'Already voted');

        loanVoters[_loanId][msg.sender] = true;
        emit LoanRequestVote(msg.sender, _loanId, _isApproved);


        if (_isApproved) {
            handleLoanApprovalVote(_loanId);
        } else {
            handleLoanRejectionVote(_loanId);
        }
    }

    function handleLoanApprovalVote(uint256 _loanId) internal {
        Loan storage loan = loans[_loanId];
        
        require(loan.amount <= amountDeposited, 'Not enough funds')
        
        loan.approvalCount++;
        
        if (isMajority(loan.approvalCount)) {
            loan.status = LoanStatus.Approved;
            amountApproved += loan.amount;
            amountDeposited -= loan.amount;
            emit LoanApproved(_loanId, loan.approvalCount, loan.rejectionCount);
        }
    }

    function handleLoanRejectionVote(uint256 _loanId) internal {
        Loan storage loan = loans[_loanId];
        loan.rejectionCount++;
        
        if (isMajority(loan.rejectionCount)) {
            loan.status = LoanStatus.Rejected;
            emit LoanRejected(_loanId, loan.approvalCount, loan.rejectionCount);
        }
    }

    // ======= HELPERS =======
    function isMajority(uint256 _votes) internal view returns(bool) {
        return _votes > members.length / 2;
    }
}
