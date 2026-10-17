TimedEscrow learning project

Reference stack: Solidity 0.8.30, Foundry 1.7.1, forge-std v1.9.7.

Install Foundry: https://getfoundry.sh/introduction/installation/
Then run from this extracted folder:

forge install foundry-rs/forge-std@v1.9.7 --no-git
forge build
forge test -vv

Full explanations, local deployment commands and limitations are in the
Persian HTML guide that contains this archive.

fund-escrow.ts is a browser integration example (viem 2.57.7).
It requires a wallet provider and your local contract address.

This is a teaching example, not an audited escrow product.
The buyer can withhold release and later receive a refund.
The contract cannot verify delivery. It has no dispute resolution,
upgrades, emergency admin, or recovery of surplus ETH / accidental tokens.
