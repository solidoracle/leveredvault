import { ethers } from 'ethers';
import { useAccount, useBalance } from 'wagmi';
import { LEVEREDVAULT_TOKEN_ADDRESS } from '~~/utils/constants';

export const useLvtBalance = () => {
  const { address } = useAccount();

  const { data: lvtBalance } = useBalance({
    address: address,
    token: LEVEREDVAULT_TOKEN_ADDRESS,
  });

  return { lvtBalance: lvtBalance?.formatted ? lvtBalance.formatted : '0.000' };
};
