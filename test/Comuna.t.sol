// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { Comuna } from  "../src/Comuna.sol";
import { ERC20PresetMinterPauser } from "../lib/openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";

contract ComunaTest is Test {
    Comuna public comuna;
    ERC20PresetMinterPauser token;

    // Addresses 
    address alice = address(0x1);
    address bob = address(0x2);
    address charlie = address(0x3);
    address trudy = address(0x4); // not a member

    address chairman = alice;
    uint256 initialSharePrice = 5000000; // 6 decimals

    function setUp() public {
        address[] memory initialMembers = new address[](3);
        initialMembers[0] = alice;
        initialMembers[1] = bob;
        initialMembers[2] = charlie;

        // Create token
        token = new ERC20PresetMinterPauser("Test Token", "TST");
        address tokenAddress = address(token);
        
        // Create comuna
        comuna = new Comuna(
            initialMembers,
            chairman,
            tokenAddress,
            initialSharePrice    
        );

        assertEq(address(comuna.token()), tokenAddress);
        assertEq(comuna.chairman(), chairman);
        assertEq(comuna.getSharePrice(), initialSharePrice);
        assertEq(comuna.getMembers().length, 3);
        assertEq(comuna.getMembers()[0], alice);
        assertEq(comuna.getMembers()[1], bob);
        assertEq(comuna.getMembers()[2], charlie);
    }

    // Start Period
    function test_startPeriod() public {
        vm.startPrank(chairman);
        comuna.startPeriod();
        assertEq(comuna.currentPeriod(), 1);
        assertEq(comuna.isCurrentPeriodActive(), true);
        assertEq(comuna.nextPeriodStartTime(), block.timestamp);
    }

    function test_revertIfNotChairmanStartPeriod() public {
        vm.expectRevert('not the chairman');
        comuna.startPeriod();
    }

    function test_revertIfCurrentPeriodActiveStartPeriod() public {
        vm.startPrank(chairman);
        comuna.startPeriod();
        vm.expectRevert('period already active');
        comuna.startPeriod();
    }

    // End Period
    function test_endPeriod() public {
        vm.startPrank(chairman);
        comuna.startPeriod();
        comuna.endPeriod();
        assertEq(comuna.currentPeriod(), 1);
        assertEq(comuna.isCurrentPeriodActive(), false);
        assertEq(comuna.nextPeriodStartTime(), block.timestamp + comuna.PERID_DURATION());
    }

    function test_revertIfNotChairmanEndPeriod() public {
        vm.expectRevert('not the chairman');
        comuna.endPeriod();
    }

    function test_revertIfPeriodNotActiveEndPeriod() public {
        vm.startPrank(chairman);
        vm.expectRevert('period not active');
        comuna.endPeriod();
    }

    // Deposit
    function test_deposit () public {
        uint256 amount = 10000000; // 6 decimals
        token.mint(chairman, amount);

        vm.startPrank(chairman);
        comuna.startPeriod();
        token.approve(address(comuna), amount);
        comuna.deposit(amount);

        assertEq(comuna.capitalDeposited(), amount);
        assertEq(comuna.getDepositBalance(chairman), amount);
        assertEq(comuna.getDepositCount(1), 1);
        assertEq(comuna.getSharesOwned(chairman), 20000);
        assertEq(token.balanceOf(address(comuna)), amount);
    }

    function test_revertDepositIfNotOpen() public { 
        vm.startPrank(bob);
        vm.expectRevert('deposits are not open');
        comuna.deposit(10000000);
    }

    function test_revertDepositIfAmountIsZero () public {
        vm.startPrank(chairman);
        comuna.startPeriod();
        vm.expectRevert('amount must be greater than 0');
        comuna.deposit(0);
    }

    function test_revertDepositIfInsufficientAllowance () public {
        uint256 amount = 10000000; // 6 decimals
        token.mint(chairman, amount);

        vm.startPrank(chairman);
        comuna.startPeriod();
        token.approve(address(comuna), amount);
        vm.expectRevert('ERC20: insufficient allowance');
        comuna.deposit(amount + 1);
    }
}
