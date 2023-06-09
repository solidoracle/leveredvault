import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

/**
 * Deploys a contract named "YourContract" using the deployer account and
 * constructor arguments set to the deployer address
 *
 * @param hre HardhatRuntimeEnvironment object.
 */
const deployYourContract: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  /*
    On localhost, the deployer account is the one that comes with Hardhat, which is already funded.

    When deploying to live networks (e.g `yarn deploy --network goerli`), the deployer account
    should have sufficient balance to pay for the gas fees for contract creation.

    You can generate a random account with `yarn generate` which will fill DEPLOYER_PRIVATE_KEY
    with a random private key in the .env file (then used on hardhat.config.ts)
    You can run the `yarn account` command to check your balance in every network.
  */
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const wmaticAddress = "0xf237dE5664D3c2D2545684E76fef02A3A58A364c";
  const aaveLendingPoolAddress = "0x0b913A76beFF3887d35073b8e5530755D60F78C7";
  const aaveRewardsAddress = "0x67D1846E97B6541bA730f0C24899B0Ba3Be0D087";
  const leverage = true;
  const borrowPercentage = 25;
  const maticUsdPriceFeed = "0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada";

  await deploy("LeveredVault", {
    from: deployer,
    // Contract constructor arguments
    args: [
      wmaticAddress,
      deployer,
      aaveLendingPoolAddress,
      aaveRewardsAddress,
      leverage,
      borrowPercentage,
      maticUsdPriceFeed,
    ],
    log: true,
    // autoMine: can be passed to the deploy function to make the deployment process faster on local networks by
    // automatically mining the contract deployment transaction. There is no effect on live networks.
    autoMine: true,
  });

  // Get the deployed contract
  // const yourContract = await hre.ethers.getContract("YourContract", deployer);
};

export default deployYourContract;

// Tags are useful if you have multiple deploy files and only want to run one of them.
// e.g. yarn deploy --tags YourContract
deployYourContract.tags = ["YourContract"];
