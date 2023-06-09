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


contract leveredVaultTest is Test {
    LeveredVault public leveredVault;
    address owner = address(0x01);
    // POLYGON MAINNET CONFIG
    WMATIC wmatic = WMATIC(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270);
    address aaveLendingPoolAddress = address(0x794a61358D6845594F94dc1DB02A252b5b4814aD); 
    address aaveRewards = address(0x64b761D848206f447Fe2dd461b0c635Ec39EbB27);
    bool leverage = false;
    uint8 borrowPercentage = 25;
    address maticUsdPriceFeed = address(0xAB594600376Ec9fD91F8e885dADF0CE036862dE0);

    // POLYGON MUMBAI CONFIG
    // WMATIC wmatic = WMATIC(0xf237dE5664D3c2D2545684E76fef02A3A58A364c);
    // address aaveLendingPoolAddress = address(0x0b913A76beFF3887d35073b8e5530755D60F78C7); 
    // address aaveRewards = address(0x67D1846E97B6541bA730f0C24899B0Ba3Be0D087);
    // bool leverage = true;
    // uint8 borrowPercentage = 25;
    // address maticUsdPriceFeed = "0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada"; // curioso di sapere se questo è il feed giusto

   
    function setUp() private {
        leveredVault = new LeveredVault(ERC20(address(wmatic)), owner, aaveLendingPoolAddress, aaveRewards, leverage, borrowPercentage, maticUsdPriceFeed);
    }


    function testConstructor() private {
        ERC20 asset = leveredVault.asset();
        assertEq(address(asset), address(wmatic));
        assertEq(leveredVault.owner(), owner);
        assertEq(leveredVault.aave(), aaveLendingPoolAddress);
        assertEq(leveredVault.aaveRewards(), aaveRewards);
    }


    function testETHDeposit() private {
        (bool success, ) = address(leveredVault).call{value: 1 ether}("");

        assertEq(leveredVault.totalHoldings(), 1 ether);      
        assertEq(leveredVault.balanceOf(address(this)), 1 ether); 

        IPool aaveLendingPool = IPool(aaveLendingPoolAddress);

        address aPolWmaticAddress = aaveLendingPool.getReserveData(address(wmatic)).aTokenAddress;
        IERC20 aPolWmatic = IERC20(aPolWmaticAddress);
        assertEq(aPolWmatic.balanceOf(address(leveredVault)), 1 ether);
    }

    function testETHDepositFuzz(uint amount) private {
        amount = bound(amount, 0, 100 ether); // for goerli testing you can bound amount to address(this).balance

        wmatic.approve(address(leveredVault), amount);

        (bool success, ) = address(leveredVault).call{value: amount}("");

        assertEq(leveredVault.totalHoldings(), amount);      
        assertEq(leveredVault.balanceOf(address(this)), amount); 
    }

    function testwmaticDeposit() private {
        // wrap ETH
        wmatic.deposit{value: 1 ether}();
        uint256 initialwmaticBalance = wmatic.balanceOf(address(this));
        // approve
        wmatic.approve(address(leveredVault), 1 ether);
        // deposit on aave
        leveredVault.deposit(1 ether, address(this));
        // check balance
        assertEq(leveredVault.totalHoldings(), 1 ether);      
        assertEq(wmatic.balanceOf(address(this)), initialwmaticBalance - 1 ether);
        assertEq(leveredVault.balanceOf(address(this)), 1 ether); 

        IPool aaveLendingPool = IPool(aaveLendingPoolAddress);
        (uint256 totalLiquidityETH, , , , , ) = aaveLendingPool.getUserAccountData(address(leveredVault));

        /**The totalLiquidityETH represents the total available liquidity in the Aave pool for a specific asset,
         * in this case, wmatic. When you deposit 1 wmatic into the Aave pool, you're essentially contributing to the 
         * overall liquidity of the pool. The value you're seeing (190815786500) is not your individual deposited 
         * amount but the total liquidity in the pool, which includes your 1 wmatic deposit as well as deposits from other users.
         **/
        // assertEq(totalLiquidityETH,188763044000); // this changes on every fork

        /**
         * If you want to check your own balance on Aave after depositing, we should query the balance of the aPolWmatic 
         * (Aave interest-bearing wmatic) associated with leveredVault.
         */
        address aPolWmaticAddress = aaveLendingPool.getReserveData(address(wmatic)).aTokenAddress;
        IERC20 aPolWmatic = IERC20(aPolWmaticAddress);
        assertEq(aPolWmatic.balanceOf(address(leveredVault)), 1 ether);
    }        

    function testWithdraw() private {
        wmatic.deposit{value: 1 ether}();
        // approve
        wmatic.approve(address(leveredVault), 1 ether);
        // we MUST approve leveredVault or other address to spend our vault tokens in case they are the ones calling withdraw
        leveredVault.approve( address(leveredVault), type(uint256).max);

        // deposit on aave
        leveredVault.deposit(1 ether, address(this));

        // withdraw
        uint shares = leveredVault.balanceOf(address(this));
        uint assets = leveredVault.convertToAssets(shares);
        leveredVault.withdraw(assets, address(0x04), address(this)); // we are sending the withdrawn wmatic to address(0x04)
        assertEq(wmatic.balanceOf(address(0x04)), 1 ether);
        assertEq(leveredVault.totalHoldings(), 0);

    }

    function testWithdrawFuzz(uint amount) private {
        amount = bound(amount, 0.01 ether, 100 ether);

        (bool success, ) = address(leveredVault).call{value: amount}("");

        vm.warp(block.timestamp + 365 days);

        // withdraw
        uint shares = leveredVault.balanceOf(address(this));
        uint assets = leveredVault.convertToAssets(shares);
        leveredVault.withdraw(assets, address(0x04), address(this)); // we are sending the withdrawn wmatic to address(0x04)
        assertEq(wmatic.balanceOf(address(0x04)), amount);
        assertEq(leveredVault.totalHoldings(), 0);
    }

    function testMultipleUsers() private {
        address user1 = address(0x0a);
        address user2 = address(0x0b);
        uint amount = 1 ether;

        (bool success1, ) = user1.call{value: amount }("");
        require(success1, "Transfer failed");
        (bool success2, ) = user2.call{value: amount }("");
        require(success2, "Transfer failed");

        vm.startPrank(user1);
        address(leveredVault).call{value: 1 ether}("");
        vm.stopPrank();
        vm.startPrank(user2);
        address(leveredVault).call{value: 1 ether}("");
        vm.stopPrank();

        assertEq(leveredVault.totalHoldings(), 2 ether);

        vm.warp(block.timestamp + 30 days);

        vm.startPrank(user1);
        uint shares1 = leveredVault.balanceOf(user1);
        uint assets1 = leveredVault.convertToAssets(shares1);
        console.logString('assets1');
        console.logUint(assets1);
        leveredVault.withdraw(assets1, user1, user1);
        vm.stopPrank();
        vm.startPrank(user2);
        uint shares2 = leveredVault.balanceOf(user2);
        uint assets2 = leveredVault.convertToAssets(shares2);
        console.logString('assets2');
        console.logUint(assets2);
        leveredVault.withdraw(assets2, user2, user2);
        vm.stopPrank();
   

        assertEq(leveredVault.totalHoldings(), 0);

        assertEq(wmatic.balanceOf(address(user1)), 1 ether);
        assertEq(wmatic.balanceOf(address(user2)), 1 ether);

    }

    // only works on mainnet fork as interest needs to be accrued overtime
    function testHarvest() private {
        uint depositAmount = 1 ether;

        (bool success, ) = address(leveredVault).call{value: depositAmount}("");

        assertEq(leveredVault.totalHoldings(), depositAmount);      
        assertEq(leveredVault.balanceOf(address(this)), depositAmount); 

        IPool aaveLendingPool = IPool(aaveLendingPoolAddress);

        address aPolWmaticAddress = aaveLendingPool.getReserveData(address(wmatic)).aTokenAddress;
        IaPolWmatic aPolWmatic = IaPolWmatic(aPolWmaticAddress);
        assertEq(aPolWmatic.balanceOf(address(leveredVault)), depositAmount);

        uint256 scaledBalanceBefore = aPolWmatic.scaledBalanceOf(address(leveredVault));

        // Advance the blockchain by a certain number of blocks to simulate time passing
        vm.warp(block.timestamp + 365 days);

        // someone else deposits for the update of the liquidity index, and the update of the interest rate
        vm.startPrank(address(owner));
        wmatic.deposit{value: 1 ether}();
        WMATIC(wmatic).approve(address(aaveLendingPool), 1 ether);
        aaveLendingPool.supply(address(wmatic), 1 ether, owner, 0);

        uint256 scaledBalance = aPolWmatic.scaledBalanceOf(address(leveredVault));
        uint256 intermediateResult = FixedPointMathLib.mulWadDown(scaledBalance, aaveLendingPool.getReserveData(address(wmatic)).liquidityIndex);
        uint balanceThisHarvest = FixedPointMathLib.mulDivDown(intermediateResult, 1e18, 1e27);

    
        uint256 expectedYield = balanceThisHarvest - depositAmount;

        uint256 oldTotalHoldings = leveredVault.totalHoldings();

        leveredVault.harvest();

        // Verify yield was correctly transferred
        uint256 yield = balanceThisHarvest > oldTotalHoldings ? balanceThisHarvest - oldTotalHoldings : 0;
  
        assertEq(yield, expectedYield);
    }

    // only works on mainnet fork as interest needs to be accrued overtime
    function testFee() private {
        uint depositAmount = 1 ether;

        (bool success, ) = address(leveredVault).call{value: depositAmount}("");

        assertEq(leveredVault.totalHoldings(), depositAmount);      
        assertEq(leveredVault.balanceOf(address(this)), depositAmount); 

        IPool aaveLendingPool = IPool(aaveLendingPoolAddress);

        address aPolWmaticAddress = aaveLendingPool.getReserveData(address(wmatic)).aTokenAddress;
        IaPolWmatic aPolWmatic = IaPolWmatic(aPolWmaticAddress);
        assertEq(aPolWmatic.balanceOf(address(leveredVault)), depositAmount);


        uint256 scaledBalanceBefore = aPolWmatic.scaledBalanceOf(address(leveredVault));
        DataTypes.ReserveData memory reserveData = aaveLendingPool.getReserveData(address(wmatic));

        // Advance the blockchain by a certain number of blocks to simulate time passing
        vm.warp(block.timestamp + 365 days);

        // someone else deposits for the update of the liquidity index and interest (!)
        vm.startPrank(address(owner));
        wmatic.deposit{value: 1 ether}();
        WMATIC(wmatic).approve(address(aaveLendingPool), 1 ether);
        aaveLendingPool.supply(address(wmatic), 1 ether, owner, 0);
        
        uint feePercent = 1e8;
        leveredVault.setFeePercent(feePercent);
        assertEq(leveredVault.feePercent(), feePercent);

        uint256 oldTotalHoldings = leveredVault.totalHoldings();
        leveredVault.harvest();

        uint256 scaledBalance = aPolWmatic.scaledBalanceOf(address(leveredVault));
        console.logUint(aaveLendingPool.getReserveData(address(wmatic)).liquidityIndex);
        uint256 intermediateResult = FixedPointMathLib.mulWadDown(scaledBalance, aaveLendingPool.getReserveData(address(wmatic)).liquidityIndex);
        uint balanceThisHarvest = FixedPointMathLib.mulDivDown(intermediateResult, 1e18, 1e27);
        uint256 yield = balanceThisHarvest > oldTotalHoldings ? balanceThisHarvest - oldTotalHoldings : 0;
        // Calculate the expected fee
        uint256 expectedFee = FixedPointMathLib.mulDivDown(yield, feePercent, 1e18);

        // Get the actual fee from leveredVault's own balance
        uint256 actualFee = leveredVault.balanceOf(address(leveredVault));

        // Check if the actual fee matches the expected fee
        assertEq(actualFee, expectedFee);
    }
}