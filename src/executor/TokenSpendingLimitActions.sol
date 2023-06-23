// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.19;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract TokenSpendingLimitActions {
    function transferLimitAction(address _token, uint256 _amount, address _to) external {
        IERC20(_token).transfer(_to, _amount);
    }
}
