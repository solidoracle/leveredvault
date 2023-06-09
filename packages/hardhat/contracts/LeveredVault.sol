//SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import { SafeTransferLib, ERC4626, ERC20 } from "solmate/src/mixins/ERC4626.sol";
import "solmate/src/auth/Owned.sol";
import "solmate/src/utils/FixedPointMathLib.sol";
import "solmate/src/utils/ReentrancyGuard.sol";
import "solmate/src/utils/SafeCastLib.sol";
import "solmate/src/tokens/WETH.sol";
import "./Interfaces/aave/IPool.sol";
import "./Interfaces/aave/IAWETH.sol";
import "./Interfaces/aave/IRewardsController.sol";
import "./Interfaces/IWMATIC.sol";
import  { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {console} from "../lib/forge-std/src/console.sol";
import  { AggregatorV3Interface } from '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';

/**
 * @author @solidoracle
 *
 * An ERC4626 vault that deposits on aave with leveradge and float
 * 
 *  /$$       /$$$$$$$$ /$$    /$$ /$$$$$$$$ /$$$$$$$  /$$$$$$$$ /$$$$$$$  /$$    /$$  /$$$$$$  /$$   /$$ /$$    /$$$$$$$$
 * | $$      | $$_____/| $$   | $$| $$_____/| $$__  $$| $$_____/| $$__  $$| $$   | $$ /$$__  $$| $$  | $$| $$   |__  $$__/
 * | $$      | $$      | $$   | $$| $$      | $$  \ $$| $$      | $$  \ $$| $$   | $$| $$  \ $$| $$  | $$| $$      | $$   
 * | $$      | $$$$$   |  $$ / $$/| $$$$$   | $$$$$$$/| $$$$$   | $$  | $$|  $$ / $$/| $$$$$$$$| $$  | $$| $$      | $$   
 * | $$      | $$__/    \  $$ $$/ | $$__/   | $$__  $$| $$__/   | $$  | $$ \  $$ $$/ | $$__  $$| $$  | $$| $$      | $$   
 * | $$      | $$        \  $$$/  | $$      | $$  \ $$| $$      | $$  | $$  \  $$$/  | $$  | $$| $$  | $$| $$      | $$   
 * | $$$$$$$$| $$$$$$$$   \  $/   | $$$$$$$$| $$  | $$| $$$$$$$$| $$$$$$$/   \  $/   | $$  | $$|  $$$$$$/| $$$$$$$$| $$   
 * |________/|________/    \_/    |________/|__/  |__/|________/|_______/     \_/    |__/  |__/ \______/ |________/|__/   
 *                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            
 */


contract LeveredVault is ERC4626, Owned, ReentrancyGuard {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;    
    using SafeCastLib for uint256;
    uint256 internal immutable BASE_UNIT;
    uint256 public totalHoldings;
    uint256 public strategyBalance; // used in harvest, but not set in deposit or deducted from withdraw
    ERC20 public immutable UNDERLYING;
    uint256 public feePercent;

    bool public leverageStakingYieldToggle;
    uint8 public borrowPercentage;
    AggregatorV3Interface immutable priceFeedMatic;

    // https://docs.aave.com/developers/deployed-contracts/v3-testnet-addresses
    address public immutable aave; 
    address public immutable aaveRewards;

    constructor(
        ERC20 _UNDERLYING, 
        address _owner, 
        address _aave, 
        address _aaveRewards, 
        bool _leverageStakingYieldToggle,
        uint8 _borrowPercentage,
        address _priceFeedMatic
    )
        ERC4626(_UNDERLYING, "LeveredVault", "LVT")
        Owned(_owner)
    {
        aave = _aave;
        aaveRewards = _aaveRewards;
        leverageStakingYieldToggle = _leverageStakingYieldToggle;
        borrowPercentage = _borrowPercentage;
        priceFeedMatic = AggregatorV3Interface(_priceFeedMatic);
        // implicitly inherited from ERC20, which is passed as an argument to the ERC4626 constructor. 
        BASE_UNIT = 10**decimals;
        UNDERLYING = _UNDERLYING;
    }

    /*///////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @inheritdoc ERC4626
     */
    function afterDeposit(uint256 assets, uint256) internal override nonReentrant {
        // deposit assets to Aave
        ERC20(asset).approve(aave, assets);
        // we are not considering the float here -- we are depositing everything
        IPool(aave).supply(address(asset), assets, address(this), 0);
        // Increase totalHoldings to account for the deposit.
        totalHoldings += assets;

        // Leverage 
        if (leverageStakingYieldToggle) {
        (uint256 _supplied, uint256 _borrowed, , , , ) = getAaveUserAccountData();

        uint256 _toBeBorrowedUSD = (_supplied * borrowPercentage) / 100;


        if (_toBeBorrowedUSD > _borrowed) {
            _toBeBorrowedUSD -= _borrowed;
            (, int256 _priceWMatic, , , ) = getPriceFeedWMatic();

            uint256 _toBeBorrowed = (_toBeBorrowedUSD * (10 ** 18)) / uint256(_priceWMatic);

            IPool(aave).borrow(address(this.asset()), _toBeBorrowed, 2, 0, address(this));
    
            uint newWMaticBalance = WMATIC(payable(address(asset))).balanceOf(address(this));
            ERC20(asset).approve(aave, newWMaticBalance);
            IPool(aave).supply(address(asset), newWMaticBalance, address(this), 0);
        }
    }
}
    
    function getAaveUserAccountData()
    public
    view
    returns (
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    )
        {
            (
                uint256 _totalCollateralBase,
                uint256 _totalDebtBase,
                uint256 _availableBorrowsBase,
                uint256 _currentLiquidationThreshold,
                uint256 _ltv,
                uint256 _healthFactor
            ) = IPool(aave).getUserAccountData(address(this));
            return (
                _totalCollateralBase,
                _totalDebtBase,
                _availableBorrowsBase,
                _currentLiquidationThreshold,
                _ltv,
                _healthFactor
            );
        }

    function getPriceFeedWMatic()
    public
    view
    returns (uint80 roundID, int256 price, uint256 startedAt, uint256 timeStamp, uint80 answeredInRound)
        {
        (
            uint80 _roundID,
            int256 _price,
            uint256 _startedAt,
            uint256 _timeStamp,
            uint80 _answeredInRound
        ) = priceFeedMatic.latestRoundData();
        return (_roundID, _price, _startedAt, _timeStamp, _answeredInRound);
        }

    function beforeWithdraw(uint256 assets, uint256) internal override {
        // Retrieve underlying tokens from strategy/float.
        retrieveUnderlying(assets);
    }

    /// @dev Retrieves a specific amount of underlying tokens held in the strategy and/or float.
    /// @dev Only withdraws from strategies if needed and maintains the target float percentage if possible.
    /// @param underlyingAmount The amount of underlying tokens to retrieve.
    function retrieveUnderlying(uint256 underlyingAmount) internal {
        pullFromStrategy(underlyingAmount);
    }

    /*///////////////////////////////////////////////////////////////
                        STRATEGY WITHDRAWAL LOGIC
    //////////////////////////////////////////////////////////////*/

    function pullFromStrategy(uint256 underlyingAmount) public {
        if (leverageStakingYieldToggle) {
            (uint256 _supplied, uint256 _borrowed, , , , ) = getAaveUserAccountData();
            (, int256 _priceWMatic, , , ) = getPriceFeedWMatic();
            uint repayMatic = (_borrowed * (10 ** 18)) / uint256(_priceWMatic);
    
            IPool(aave).repayWithATokens(address(asset), repayMatic, 2);
        }


        IPool(aave).withdraw(address(asset), underlyingAmount, address(this));

        unchecked {
            // Account for the withdrawal done
            // Cannot underflow as the balances of some strategies cannot exceed the sum of all.
            totalHoldings -= underlyingAmount;
        }
    }

    /*///////////////////////////////////////////////////////////////
                        VAULT ACCOUNTING LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Calculates the total amount of underlying tokens the Vault holds.
    /// @return totalUnderlyingHeld The total amount of underlying tokens the Vault holds.
    function totalAssets() public view override returns (uint256 totalUnderlyingHeld) {
        unchecked {
            totalUnderlyingHeld = totalHoldings;
        }
    }

    function totalFloat() public view returns (uint256) {
        return UNDERLYING.balanceOf(address(this));
    }
    
    /*///////////////////////////////////////////////////////////////
                             HARVEST LOGIC
    //////////////////////////////////////////////////////////////*/

    function harvest() external onlyOwner {
        // Get the Vault's current total strategy holdings.
        uint256 oldTotalHoldings = totalHoldings;

        // Used to store the total profit accrued by the aave strategy.
        uint256 totalProfitAccrued;

        // Used to store the new total strategy holdings after harvesting.
        uint256 newTotalHoldings = oldTotalHoldings;
    
        // Get the strategy's previous and current balance.
        uint256 balanceLastHarvest = totalHoldings; // could use strategyBalance?

        IPool aaveLendingPool = IPool(aave);

        DataTypes.ReserveData memory reserveData = aaveLendingPool.getReserveData(address(asset));
        address aWETHAddress = reserveData.aTokenAddress;
        uint256 index = reserveData.liquidityIndex;

        IAWETH aWETH = IAWETH(aWETHAddress);

        uint256 scaledBalance = aWETH.scaledBalanceOf(address(this));
        uint256 intermediateResult = FixedPointMathLib.mulWadDown(scaledBalance, index);
        uint balanceThisHarvest = FixedPointMathLib.mulDivDown(intermediateResult, 1e18, 1e27);

        // Increase/decrease newTotalHoldings based on the profit/loss registered.
        newTotalHoldings = newTotalHoldings + balanceThisHarvest - balanceLastHarvest;
        
        unchecked {
            // Update the total profit accrued while counting losses as zero profit.
            totalProfitAccrued += balanceThisHarvest > balanceLastHarvest
                ? balanceThisHarvest - balanceLastHarvest // Profits since last harvest.
                : 0; // If the strategy registered a net loss we don't have any new profit.
        }

        // Compute fees as the fee percent multiplied by the profit.
        uint256 feesAccrued = totalProfitAccrued.mulDivDown(feePercent, 1e18);
    
        // If we accrued any fees, mint an equivalent amount of rvTokens.
        _mint(address(this), feesAccrued.mulDivDown(BASE_UNIT, convertToAssets(BASE_UNIT)));
    
        // Set total holdings to our new total.
        totalHoldings = newTotalHoldings;
    }
    

    /*///////////////////////////////////////////////////////////////
                             FEE & REWARD CLAIM LOGIC
    //////////////////////////////////////////////////////////////*/

    function claimFees(uint256 amount) external onlyOwner {
        // Transfer the provided amount of rvTokens to the caller.
        asset.safeTransfer(msg.sender, amount);
    }

    // TODO: not sure when to call this
    function claimAaveRewards(address[] calldata _assets, address _to) external onlyOwner {
        IRewardsController(aaveRewards).claimAllRewards(_assets, _to);
    }

    /// @notice Emitted when the fee percentage is updated.
    /// @param user The authorized user who triggered the update.
    /// @param newFeePercent The new fee percentage.
    event FeePercentUpdated(address indexed user, uint256 newFeePercent);

    /// @notice Sets a new fee percentage.
    /// @param newFeePercent The new fee percentage.
    function setFeePercent(uint256 newFeePercent) external onlyOwner {
        // A fee percentage over 100% doesn't make sense.
        require(newFeePercent <= 1e18, "FEE_TOO_HIGH");

        // Update the fee percentage.
        feePercent = newFeePercent;

        emit FeePercentUpdated(msg.sender, newFeePercent);
    }

    /*///////////////////////////////////////////////////////////////
                             POOL DATA
    //////////////////////////////////////////////////////////////*/

    function getReserveData(address asset) external view returns (uint256 liquidityRate, uint40 lastUpdateTimestamp) {
        DataTypes.ReserveData memory reserve =
        IPool(aave).getReserveData(asset);

        return (
            reserve.currentLiquidityRate,
            reserve.lastUpdateTimestamp
        );
    }

    /*///////////////////////////////////////////////////////////////
                          RECIEVE ETHER LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @dev Required for the Vault to receive unwrapped ETH.
    receive() external payable {
        // Convert the MATIC to WMATIC
        WMATIC(payable(address(asset))).deposit{value: msg.value}();

        // Deposit the WMATIC to the Vault
        this.deposit(msg.value, msg.sender);
     }

}
