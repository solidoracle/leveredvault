import {
  Button,
  Divider,
  Grid,
  GridItem,
  NumberDecrementStepper,
  NumberIncrementStepper,
  NumberInput,
  NumberInputField,
  NumberInputStepper,
  TabPanel,
  Text,
} from '@chakra-ui/react';
import { Error } from '~~/components/Error';
import { useLvtBalance } from '~~/hooks/other/useLvtBalance';
import { useWithdraw } from '~~/hooks/other/useWithdraw';

export const Withdraw = () => {
  const { lvtBalance } = useLvtBalance();
  const { handleWithdraw, withdrawValue, setWithdrawValue, isWithdrawProcessing } = useWithdraw();
  const insufficientFunds = Number(lvtBalance) < withdrawValue;

  return (
    <TabPanel px={0}>
      <form>
        <Grid alignItems="center" gridTemplateColumns={'1.4fr 1fr'} gap={4} mb={5}>
          <GridItem>
            <NumberInput
              min={0}
              onChange={(_stringVal, numberVal) => {
                setWithdrawValue(numberVal);
              }}>
              <NumberInputField />
              <NumberInputStepper>
                <NumberIncrementStepper />
                <NumberDecrementStepper />
              </NumberInputStepper>
            </NumberInput>
          </GridItem>
          <GridItem>
            <Text fontSize="lg" my={0}>
              LVT
            </Text>
          </GridItem>
        </Grid>
        <Divider orientation="horizontal" />
        <Button colorScheme="purple" width="100%" isLoading={isWithdrawProcessing} onClick={() => handleWithdraw?.()}>
          Withdraw
        </Button>
        {insufficientFunds && (
          <Error
            errorTitle="Warning"
            errorDescription="You have insufficient funds to complete this withdrawal. Please alter the withdraw amount before continuing."
          />
        )}
      </form>
    </TabPanel>
  );
};
