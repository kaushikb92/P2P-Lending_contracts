pragma solidity ^0.4.8;

import "./SafeMath.sol";

library EMICalculator {
	function calculateInstallment(
        uint256 _amount,
        uint _rateOfInterest,
        uint _tenureInMonths) internal pure returns (
        uint installmentAmount)
	{
		return (SafeMath.div(SafeMath.add(_amount, (SafeMath.div((SafeMath.mul(_amount, _rateOfInterest)), 100))), _tenureInMonths));
	}
}