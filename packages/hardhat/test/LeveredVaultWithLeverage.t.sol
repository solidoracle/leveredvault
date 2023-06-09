// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/LeveredVault.sol";
import { Vm } from 'forge-std/Vm.sol';
import  { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "../contracts/Interfaces/aave/IPool.sol";
import "../contracts/Interfaces/IWMATIC.sol";

import {console} from "../lib/forge-std/src/console.sol";


interface WMaticInterface is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}


contract leveredVaultWithLeverageTest is Test {
    LeveredVault public leveredVault;
    address owner = address(0x01);
    // POLYGON MAINNET CONFIG
    WMATIC wmatic = WMATIC(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
    address aaveLendingPoolAddress = address(0x794a61358D6845594F94dc1DB02A252b5b4814aD); 
    address aaveRewards = address(0x64b761D848206f447Fe2dd461b0c635Ec39EbB27);
    bool leverage = true;
    uint8 borrowPercentage = 25;
    address maticUsdPriceFeed = address(0xAB594600376Ec9fD91F8e885dADF0CE036862dE0);

    // POLYGON MUMBAI CONFIG
    // WMATIC wmatic = WMATIC(0xf237dE5664D3c2D2545684E76fef02A3A58A364c);
    // address aaveLendingPoolAddress = address(0x0b913A76beFF3887d35073b8e5530755D60F78C7); 
    // address aaveRewards = address(0x67D1846E97B6541bA730f0C24899B0Ba3Be0D087);
    // bool leverage = true;
    // uint8 borrowPercentage = 25;
    // address maticUsdPriceFeed = "0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada"; // curioso di sapere se questo è il feed giusto

   
    function setUp() public {
        leveredVault = new LeveredVault(ERC20(address(wmatic)), owner, aaveLendingPoolAddress, aaveRewards, leverage, borrowPercentage, maticUsdPriceFeed);
    }


    function testConstructor() public {
        ERC20 asset = leveredVault.asset();
        assertEq(address(asset), address(wmatic));
        assertEq(leveredVault.owner(), owner);
        assertEq(leveredVault.aave(), aaveLendingPoolAddress);
        assertEq(leveredVault.aaveRewards(), aaveRewards);
    }


    function testLeverageDeposit() public {
        (bool success, ) = address(leveredVault).call{value: 1 ether}("");

        assertEq(leveredVault.totalHoldings(), 1 ether);      
        assertEq(leveredVault.balanceOf(address(this)), 1 ether); 

        IPool aaveLendingPool = IPool(aaveLendingPoolAddress);

        address aPolWmaticAddress = aaveLendingPool.getReserveData(address(wmatic)).aTokenAddress;
        IERC20 aPolWmatic = IERC20(aPolWmaticAddress);

        (
            uint256 _totalCollateralBase,
            uint256 _totalDebtBase,
            uint256 _availableBorrowsBase,
            uint256 _currentLiquidationThreshold,
            uint256 _ltv,
            uint256 _healthFactor
        ) = IPool(aaveLendingPool).getUserAccountData(address(leveredVault));

        (, int256 _priceWMatic, , , ) = leveredVault.getPriceFeedWMatic();

        uint borrowedMatic = (_totalDebtBase * (10 ** 18)) / uint256(_priceWMatic); // need amount in matic
        assertEq(aPolWmatic.balanceOf(address(leveredVault)), 1 ether + borrowedMatic);
    }

    function testLeverageWithdraw() public {
        (bool success, ) = address(leveredVault).call{value: 1 ether}("");

        vm.warp(block.timestamp + 365 days);


        uint shares = leveredVault.balanceOf(address(this));
        uint assets = leveredVault.convertToAssets(shares);
        leveredVault.withdraw(assets, address(this), address(this)); 
 
        assertEq(wmatic.balanceOf(address(this)), 1 ether); // no interest received as no harvest has been made?
    }

  
}