// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { Comuna } from  "../src/Comuna.sol";
import { ComunaFactory } from "../src/ComunaFactory.sol";

contract ComunaFactoryTest is Test {
  
  function test_createComuna() public {
    address[] memory initialMembers = new address[](2);
    initialMembers[0] = address(0x1);
    initialMembers[1] = address(0x2);

    address chairman = initialMembers[0];
    uint256 initialSharePrice = 5000000; // 6 decimals

    // Create token
    address tokenAddress = address(0x3);
    
    // Create comuna
    ComunaFactory factory = new ComunaFactory();
    Comuna comuna = factory.createComuna(initialMembers, chairman, tokenAddress, initialSharePrice);

    assertEq(address(comuna.token()), tokenAddress);
    assertEq(comuna.chairman(), chairman);
    assertEq(comuna.getSharePrice(), initialSharePrice);
    assertEq(comuna.getMembers().length, 2);
    assertEq(comuna.getMembers()[0], address(0x1));
    assertEq(comuna.getMembers()[1], address(0x2));

    assertEq(factory.getComunas().length, 1);
    assertEq(address(factory.getComunas()[0]), address(comuna));
    assertEq(factory.isComuna(address(comuna)), true );
  }

  function test_isNotComuna() public {
    ComunaFactory factory = new ComunaFactory();
    bool isComuna = factory.isComuna(address(0x1));

    assertEq(isComuna, false);
  }
}