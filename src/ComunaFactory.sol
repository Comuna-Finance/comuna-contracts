// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Comuna } from './Comuna.sol';

contract ComunaFactory {

  event ComunaCreated(address indexed comuna, address deployer, address token);
  
  Comuna[] internal comunas;

  function createComuna(address[] memory _initialMembers, address _chairman, address _token, uint256 _initialSharePrice) public returns (Comuna) {
    Comuna comuna = new Comuna(_initialMembers, _chairman, _token, _initialSharePrice);
    comunas.push(comuna);

    emit ComunaCreated(address(comuna), msg.sender, _token);

    return comuna;
  }

  function getComunas() public view returns (Comuna[] memory) {
    return comunas;
  }

  function isComuna(address _comuna) public view returns (bool) {
    for (uint i = 0; i < comunas.length; i++) {
      if (address(comunas[i]) == _comuna) {
        return true;
      }
    }
    return false;
  }
}