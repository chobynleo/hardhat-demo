// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Test {

  struct Args {
    address token;
    address tokenOut;
    uint256 a;
    uint256 b;
  }

  function test(Args calldata args) public view  returns (uint256) {
    return args.a;
  }
}
