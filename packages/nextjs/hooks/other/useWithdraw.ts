import { useState } from 'react';
import {
  useAccount,
  useContractWrite,
  usePrepareContractWrite,
  usePrepareSendTransaction,
  useSendTransaction,
  useWaitForTransaction,
} from 'wagmi';
import { LEVEREDVAULT_ABI, LEVEREDVAULT_CONTRACT_ADDRESS } from '~~/utils/constants';
import { parseEther } from '~~/utils/parseEther';

export const useWithdraw = () => {
  const { address } = useAccount();
  const [withdrawValue, setWithdrawValue] = useState(0);
  const [withdrawHash, setWithdrawHash] = useState('');

  const { config: withdrawConfig } = usePrepareContractWrite({
    address: LEVEREDVAULT_CONTRACT_ADDRESS,
    abi: LEVEREDVAULT_ABI,
    functionName: 'withdraw',
    args: [parseEther(withdrawValue), address, address],
  });

  const { write: withdraw } = useContractWrite({
    ...withdrawConfig,
    onSuccess(data) {
      setWithdrawHash(data.hash);
    },
  });

  const { isLoading: isWithdrawProcessing } = useWaitForTransaction({
    enabled: !!withdrawHash,
    hash: withdrawHash as `0x${string}`,
    // TODO: onSuccess: Show success toast message
    onSuccess: (data: any) => console.log('completed', data),
    // TODO: onError: Show error toast message
  });

  const handleWithdraw = () => {
    withdraw?.();
  };

  return { handleWithdraw, withdrawValue, setWithdrawValue, isWithdrawProcessing };
};
