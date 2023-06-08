import { useState } from 'react';
import { useDeposit } from '../../hooks/other/useDeposit';
import {
  Box,
  Button,
  Divider,
  Grid,
  GridItem,
  NumberDecrementStepper,
  NumberIncrementStepper,
  NumberInput,
  NumberInputField,
  NumberInputStepper,
  Select,
  TabPanel,
  Text,
} from '@chakra-ui/react';
import { ethers } from 'ethers';
import { Error } from '~~/components/Error';
import { useApprove } from '~~/hooks/other/useApprove';
import { useEthBalance } from '~~/hooks/other/useEthBalance';
import { useWethBalance } from '~~/hooks/other/useWethBalance';
import { DataPool } from '~~/services/aave/getDataPools';

export type CurrencyCode = 'MATIC' | 'WMATIC';
interface DepositProps {
  apy: DataPool['apy'];
}

// TODO: Check the APY is coming from the correct pool address
// TODO: Altering the depositValue to x number of decimal places breaks the app - needs investigating.

export const Deposit = ({ apy }: DepositProps) => {
  const { approve, allowance, isApproveProcessing } = useApprove();
  const { wmaticBalance } = useWethBalance();
  const { maticBalance } = useEthBalance();

  const { handleDeposit, depositValue, setDepositValue, isDepositProcessing } = useDeposit();
  const [currencyCode, setCurrencyCode] = useState<CurrencyCode>('MATIC');
  const noAllowanceSet = Number(ethers.utils.formatEther(allowance)) === 0;
  const allowanceToLow = Number(depositValue) > Number(ethers.utils.formatEther(allowance));
  const wmaticSelected = currencyCode === 'WMATIC';
  const maticSelected = currencyCode === 'MATIC';
  const insufficentWeth = wmaticSelected && depositValue > Number(wmaticBalance);
  const insufficientEth = maticSelected && depositValue > Number(maticBalance);
  const insufficientFunds = insufficentWeth || insufficientEth;

  return (
    <>
      <TabPanel px={0} pt={6}>
        <form>
          <Grid gridTemplateColumns={'1.4fr 1fr'} gap={4} mb={5}>
            <GridItem>
              <NumberInput
                min={0}
                onChange={(_stringVal, numberVal) => {
                  setDepositValue(numberVal);
                }}>
                <NumberInputField />
                <NumberInputStepper>
                  <NumberIncrementStepper />
                  <NumberDecrementStepper />
                </NumberInputStepper>
              </NumberInput>
            </GridItem>
            <GridItem>
              <Select onChange={e => setCurrencyCode(e.target.value as CurrencyCode)}>
                <option value="ETH">MATIC</option>
                <option value="WETH">WMATIC</option>
              </Select>
            </GridItem>
          </Grid>
          <Divider orientation="horizontal" />
          <Box display="flex" justifyContent="space-between">
            <Box>
              {wmaticSelected && (
                <Text fontSize="md" fontWeight="medium" color="gray.400">
                  WMATIC Balance: {wmaticBalance}
                </Text>
              )}
              {maticSelected && (
                <Text fontSize="md" fontWeight="medium" color="gray.400">
                  MATIC Balance: {maticBalance}
                </Text>
              )}
            </Box>
            <Box>
              <Text fontSize="md" fontWeight="medium" color="gray.400">
                {apy}% APY
              </Text>
            </Box>
          </Box>
          {(wmaticSelected && noAllowanceSet) || (wmaticSelected && allowanceToLow) ? (
            <Button
              colorScheme="green"
              mb="2"
              width="100%"
              onClick={() => approve(depositValue)}
              isLoading={isApproveProcessing}>
              Approve
            </Button>
          ) : (
            <Button
              colorScheme="purple"
              width="100%"
              onClick={() => handleDeposit({ currencyCode })}
              isDisabled={depositValue <= 0 || insufficentWeth || insufficientEth}
              isLoading={isDepositProcessing}>
              Deposit
            </Button>
          )}
          {insufficientFunds && (
            <Error
              errorTitle="Warning"
              errorDescription="You have insufficient funds to complete this deposit. Please increase your funds or alter the deposit amount before continuing."
            />
          )}
        </form>
      </TabPanel>
    </>
  );
};
