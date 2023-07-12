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

    function setUp() public {
        address[] memory initialMembers = new address[](3);
        initialMembers[0] = alice;
        initialMembers[1] = bob;
        initialMembers[2] = charlie;

        address chairman = alice;
        uint256 initialSharePrice = 5000000; // 6 decimals

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
}
