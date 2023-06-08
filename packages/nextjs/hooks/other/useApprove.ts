import { useState } from 'react';
import { BigNumber } from 'ethers';
import { useAccount, useContractRead, useContractWrite, usePrepareContractWrite, useWaitForTransaction } from 'wagmi';
import { LEVEREDVAULT_CONTRACT_ADDRESS, WMATIC_ABI, WMATIC_CONTRACT_ADDRESS } from '~~/utils/constants';
import { parseEther } from '~~/utils/parseEther';

export const useApprove = () => {
  const [allowance, setAllowance] = useState(BigNumber.from('0'));
  const [approveAmount, setApproveAmount] = useState(0);
  const { address } = useAccount();
  const [approveHash, setApproveHash] = useState('');

  useContractRead({
    address: WMATIC_CONTRACT_ADDRESS,
    abi: WMATIC_ABI,
    functionName: 'allowance',
    args: [address, LEVEREDVAULT_CONTRACT_ADDRESS],
    watch: true,
    onSuccess(data: BigNumber) {
      setAllowance(data);
    },
  });

  const { config: wethApproveConfig } = usePrepareContractWrite({
    address: WMATIC_CONTRACT_ADDRESS,
    abi: WMATIC_ABI,
    functionName: 'approve',
    args: [LEVEREDVAULT_CONTRACT_ADDRESS, parseEther(approveAmount)],
  });

  const { write: wethApprove } = useContractWrite({
    ...wethApproveConfig,
    onSuccess(data) {
      setApproveHash(data.hash);
    },
  });

  const { isLoading: isApproveProcessing } = useWaitForTransaction({
    enabled: !!approveHash,
    hash: approveHash as `0x${string}`,
    // TODO: onSuccess: Show success toast message
    onSuccess: (data: any) => console.log('completed', data),
    // TODO: onError: Show error toast message
  });

  const approve = async (amount: number) => {
    setApproveAmount(amount);
    await wethApprove?.();
  };

  return { allowance, approve, isApproveProcessing };
};
