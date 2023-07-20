# Comuna Finance
---
Comuna Finance is a decentralized finance protocol built on the Ethereum blockchain. It allows communities to pool funds to lend and borrow to each other, thereby fostering a cooperative, supportive, and financially inclusive ecosystem.

Through this protocol, communities can collectively pool funds, establish their lending parameters, and provide microloans to their members. The protocol's fundamental ethos is built around trust, cooperation, and financial empowerment of individual communities. 


## Key Features
---
- **Community-Driven Finance:** Comuna Finance allows communities to establish their microfinance banks, fostering a community-driven approach to lending and borrowing.
  
- **Peer-to-Peer Lending:** The protocol facilitates peer-to-peer lending, ensuring that funds are directly transferred from lenders to borrowers within the same community, without intermediaries.
  
- **Customizable Loan Parameters:** Each community can set its loan parameters, including interest rates, loan durations, and collateral requirements, ensuring the system works best for their specific needs.

## Installation
---
Requires [Foundry](https://book.getfoundry.sh/getting-started/installation)

**Step 1: Clone the Repository**

```bash
git clone https://github.com/Comuna-Finance/comuna-contracts.git
cd comuna-contracts
```

**Step 2: Compile Contracts**

```bash
forge build
```

**Step 3: Run Local Testnet Node**

```bash
anvil --port 8545
```

**Step 4: Run Tests**

```bash
forge test
```

## Contracts
---
The Comuna Finance protocol consists of two main contracts:

### Comuna Factory

The Comuna Factory contract is responsible for the creation and tracking of all Comuna contracts. 

### Comuna
The Comuna contract represents an individual community bank. It stores the state of the bank, including its pooled funds, active loans, and members. This contract also contains the logic for lending and borrowing within the community, including interest rates, loan durations, and collateral requirements.

## License
---
Comuna Finance contracts are released under the [MIT license](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/LICENSE)
