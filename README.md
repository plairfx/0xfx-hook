
### 0xfx



## Overview

There is a problem right now, matter of facts multiple!

- There are not enough different stablecoins (USD, EUR where is the rest??)
- There is no volume


Forex is a industry that has almost peaked close to a 10 trillion volume in a day!..
While right now we are struggling to even overcome 1 billion volume in forex perps today says a lot about our industry focus 
towards the stablecoins.

We can wait for every country to provide legal pathway for a stablecoin and afterwards wait for a company trusted enough to cover it,
but that just won't make it in the web3 world.

We loved DAI cause of it being actually backed by a currency we consider holy.


Here is where 0xfx comes in:

The simple goal is to open up the world of forex to allow smoothly processing of all of popular FX currencies

- EUR/USD
- GBP/USD
- USD/JPY

and more..

see image.

### Contract Structure:

The Contract exists of:
- HookContract
- TradeContract
- VaultContract
- CurrencyVault
- Storage Contract


### How does it work?

Whenever an user wants to hold a foreign currency JPY or any other one, he can mint it with USDC through the currencyVault and speculate with it.
If the foreign currency rises higher than the deposited USDC, the Hookvault will back it which is deposited with PNL /market making profit and liquidity from liquidity providers.

The trading broker/platform is the one bringing in the PNL / marketmaking opportunities, whenever a user swap one of the pairs it will simply interact a afterSwap hook call which will execute any of the pending orders which will bring beautiful loop with no off-chain nodes.

Depending on the swap amount, the swap will move around the prevTick + 1 and nextTick - 1, the minus and the plus 1 is the case of not reaching the exact tick price, which we will go deeper in a bit.


![alt text](image-1.png)


### Uniswap 
AfterSwap: the afterSwap logic will be called after every swap of a Pool (e.g. EUR/USD), this executes the earliest order of the tickRange and price.
BeforeInitialize: Whenever a newPool is inted this beforeInit is called to make sure the pool is verified in the Trade Contract.



### Tick Range
Whenever an user places a pending order think about SL TP, limit etc, the getTickRange function will calculate the tickrange position
between prevTick price + 1 and nextTickPrice -1 , which will split into 20 tickIntervals.

The user will be placed into one of those 20 tickIntervals depending on the his SqrtPricex96 and which side of a trade he chooses.
(It gets rounded up in his favour!).

![Tick range example](image.png)
Blue + red are both in the tickRange.



### Liquidity Vault
The Liquidity vault is an almost sure-way for the user to get a decent guarantee that his currencies will be compensated during a withdraw,
whenever a user mints his currency through the CurrencyVault he will always be ensured of his USDC deposit.

Whenever a user trades wins/loses he is in a battle vs the Vault. If the Vault wins the protocol win, as every trading platform the platform has to remain
mostly profitable.

![alt text](image-2.png)