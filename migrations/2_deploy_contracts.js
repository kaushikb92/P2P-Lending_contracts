var CollectFund = artifacts.require("./CollectFund.sol");
var EMICalculator = artifacts.require("./EMICalculator.sol");
var PayInstallments = artifacts.require("./PayInstallments.sol");
var SafeMath = artifacts.require("./SafeMath.sol");

module.exports = function(deployer) {
    deployer.deploy(SafeMath);
    deployer.link(SafeMath,CollectFund);
    deployer.deploy(CollectFund);
    deployer.deploy(EMICalculator);
    // deployer.link(SafeMath,PayInstallemts);
    // deployer.link(EMICalculator,PayInstallemts);
    deployer.link(SafeMath,EMICalculator,CollectFund,PayInstallments);
    deployer.deploy(PayInstallments);
}

