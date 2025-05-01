module sui_contract_token_split::sui_contract_token_split {
use sui_contract_token_split::lp_token::{LP_TOKEN, LPMinterCap};
use std::address;
use std::option::none;
use std::u64;
use sui::balance;
use sui::coin::{Self, Coin, TreasuryCap};
use sui::object::{new, UID};
use sui::transfer::{public_transfer};
use sui::tx_context::{TxContext, sender};
use sui::sui::SUI;


const E_INSUFFICIENT_BALANCE: u64 = 0;
const E_INVALID_RATIO: u64 = 1;
const E_DIVISION_BY_ZERO: u64 = 2;

public struct SUI_CONTRACT_TOKEN_SPLIT has drop {}

public struct LiquidityTokenVault has key, store {
    id: UID,
    lp_tokens: Coin<LP_TOKEN>,
}

public struct LPProvider has key, store {
    id: UID,
    provider: address,
    sui_amount: u64,
    happy_amount: u64,
}



public struct MinterCap has key, store {
    id: UID,
    treasury_cap: TreasuryCap<SUI_CONTRACT_TOKEN_SPLIT>,
}

public struct LiquidityPool has key, store {
    id: UID,
    sui_reserve: Coin<SUI>,
    happy_reserve: Coin<SUI_CONTRACT_TOKEN_SPLIT>,
}

fun init(witness: SUI_CONTRACT_TOKEN_SPLIT, ctx: &mut TxContext) {
    let initial_supply = 100000000000000;

    let (treasury_cap, metadata) = coin::create_currency(
        witness,
        9,
        b"HAPPY",
        b"HAPPY token",
        b"just a test token",
        none(),
        ctx,
    );

    // Freeze metadata and mint initial tokens to sender
    let mut minter_cap = MinterCap {
        id: new(ctx),
        treasury_cap,
    };

    let new_coin = coin::mint(&mut minter_cap.treasury_cap, initial_supply, ctx);
    public_transfer(new_coin, sender(ctx));
    public_transfer(minter_cap, sender(ctx));
    public_transfer(metadata, sender(ctx));

}

public entry fun init_lp_token_vault(
    lp_token: Coin<LP_TOKEN>,
    ctx: &mut TxContext
) {
    let vault = LiquidityTokenVault {
        id: new(ctx),
        lp_tokens: lp_token,
    };

    transfer::share_object(vault);
}




public entry fun mint(
    minter_cap: &mut MinterCap,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext
) {
    let new_coin = coin::mint(&mut minter_cap.treasury_cap, amount, ctx);
    public_transfer(new_coin, recipient)
}

 public entry fun init_pool(ctx: &mut TxContext) {
        let pool = LiquidityPool {
            id: object::new(ctx),
            sui_reserve: coin::zero<SUI>(ctx),
            happy_reserve: coin::zero<SUI_CONTRACT_TOKEN_SPLIT>(ctx),
        };
        transfer::public_share_object(pool);
    }

 public entry fun provide_liquidity(
    pool: &mut LiquidityPool,
    mut sui: Coin<SUI>,
    mut happy: Coin<SUI_CONTRACT_TOKEN_SPLIT>,
    value: u64,
    tokenVault: &mut LiquidityTokenVault,
    ctx: &mut TxContext
) {
    let sui_balance = coin::value(&sui);
    let happy_balance = coin::value(&happy);

    let happy_required = value * 200;

    assert!(sui_balance >= value, E_INSUFFICIENT_BALANCE);
    assert!(happy_balance >= happy_required, E_INSUFFICIENT_BALANCE);

    // 🔍 Check pool state BEFORE adding liquidity
    let is_first_provider = coin::value(&pool.sui_reserve) == 0;

    // Split exact coins to deposit
    let sui_for_pool = coin::split(&mut sui, value, ctx);
    let happy_for_pool = coin::split(&mut happy, happy_required, ctx);

    // Add to pool
    coin::join(&mut pool.sui_reserve, sui_for_pool);
    coin::join(&mut pool.happy_reserve, happy_for_pool);

    // Track LP provider
    let lp_provider = LPProvider {
        id: object::new(ctx),
        provider: sender(ctx),
        sui_amount: value,
        happy_amount: happy_required,
    };
    transfer::public_share_object(lp_provider);

    // 💰 Only mint LP tokens if not the first provider
    if (!is_first_provider) {
        let total_sui = coin::value(&pool.sui_reserve);

        // sender percentage = (value * 1_000_000_000) / total_sui
        let share_ratio = (value * 1_000_000_000) / total_sui;

        let lp_token = coin::split(&mut tokenVault.lp_tokens, share_ratio, ctx);
        public_transfer(lp_token, sender(ctx));
    };

    // Return remaining user tokens
    public_transfer(sui, sender(ctx));
    public_transfer(happy, sender(ctx));
}


//     public entry fun provide_liquidity(
//     pool: &mut LiquidityPool,
//     mut sui: Coin<SUI>,
//     mut happy: Coin<SUI_CONTRACT_TOKEN_SPLIT>,
//     value: u64,
//     tokenVault: &mut LiquidityTokenVault,
//     lp_cap: &mut LPMinterCap,
//     ctx: &mut TxContext
// ) {
//     let sui_balance = coin::value(&sui);
//     let happy_balance = coin::value(&happy);
    
//     // Calculate required HAPPY based on 1:200 ratio
//     let happy_required = value * 200;
    
//     // Validate balances and ratio
//     assert!(sui_balance >= value, E_INSUFFICIENT_BALANCE);
//     assert!(happy_balance >= happy_required, E_INSUFFICIENT_BALANCE);

//     // Split and add liquidity to pool
//     let sui_for_pool = coin::split(&mut sui, value, ctx);
//     let happy_for_pool = coin::split(&mut happy, happy_required, ctx);

//     // Get reserves before adding liquidity
//     let total_sui_before = coin::value(&pool.sui_reserve);
    
//     coin::join(&mut pool.sui_reserve, sui_for_pool);
//     coin::join(&mut pool.happy_reserve, happy_for_pool);

//     // Check if first provider
//     if (total_sui_before == 0) {
//         // First provider - initialize LP tokens but don't send
//         let initial_lp = ((value as u128) * (happy_required as u128)).sqrt() as u64;
//         let lp_tokens = coin::mint(&mut lp_cap.treasury_cap, initial_lp, ctx);
//         coin::join(&mut tokenVault.lp_tokens, lp_tokens);
//     } else {
//         // Subsequent providers - calculate share
//         let total_sui_after = coin::value(&pool.sui_reserve);
//         let contribution_ratio = (value * 1_000_000_000) / total_sui_after;
//         let lp_to_mint = (contribution_ratio * coin::value(&tokenVault.lp_tokens)) / 1_000_000_000;
        
//         // Mint and send LP tokens
//         let lp_tokens = coin::mint(&mut lp_cap.treasury_cap, lp_to_mint, ctx);
//         public_transfer(lp_tokens, sender(ctx));
//     }

//     // Update LP provider tracking
//     let provider_addr = sender(ctx);
//     if (!exists<LPProvider>(provider_addr)) {
//         transfer::public_transfer(LPProvider {
//             id: object::new(ctx),
//             provider: provider_addr,
//             sui_amount: value,
//             happy_amount: happy_required
//         }, provider_addr);
//     } else {
//         let provider = borrow_global_mut<LPProvider>(provider_addr);
//         provider.sui_amount = provider.sui_amount + value;
//         provider.happy_amount = provider.happy_amount + happy_required;
//     }

//     // Return leftover tokens
//     public_transfer(sui, provider_addr);
//     public_transfer(happy, provider_addr);
// }

// public entry fun provide_liquidity(
//     mut sui: Coin<SUI>,
//     mut happy: Coin<SUI_CONTRACT_TOKEN_SPLIT>,
//     vault: &mut LiquidityTokenVault, // central vault holding all LP tokens
//     value: u64,
//     ctx: &mut TxContext
// ) {
//     //
// }




public entry fun calculate_price(
    pool: &LiquidityPool,
    sui_amount: u64
): u64 {
    let happy_reserve = coin::value(&pool.happy_reserve);
    let sui_reserve = coin::value(&pool.sui_reserve);

    // Check pool not empty
    if (sui_reserve == 0) {
        abort E_DIVISION_BY_ZERO;
    };

    let price_per_sui = happy_reserve / sui_reserve;
    sui_amount * price_per_sui
}


public entry fun swap_sui_to_happy(
    pool: &mut LiquidityPool,
    mut sui_payment: Coin<SUI>,
    value: u64,
    ctx: &mut TxContext
) {
    // Split the amount user wants to swap
    let new_sui = coin::split(&mut sui_payment, value, ctx);

    // Calculate how much HAPPY to give
    let happy_amt = calculate_price(pool, value);

    // Check if the pool has enough HAPPY tokens
    if (happy_amt > coin::value(&pool.happy_reserve)) {
        abort E_INSUFFICIENT_BALANCE;
    };

    // Split the required amount of HAPPY tokens from the pool
    let new_happy = coin::split(&mut pool.happy_reserve, happy_amt, ctx);

    // ✅ Only `new_sui` should be joined into the pool
    coin::join(&mut pool.sui_reserve, new_sui);

    // ✅ Transfer HAPPY tokens to the sender
    public_transfer(new_happy, sender(ctx));

    // ✅ Return leftover SUI (if any) back to the sender
    public_transfer(sui_payment, sender(ctx));
}

public entry fun burn(
    minter_cap: &mut MinterCap,
    coin: Coin<SUI_CONTRACT_TOKEN_SPLIT>
) {
    coin::burn(&mut minter_cap.treasury_cap, coin);
}

public fun calculate_sui_price(
    pool: &LiquidityPool,
    happy_amount: u64
): u64 {
    let happy_reserve = coin::value(&pool.happy_reserve);
    let sui_reserve = coin::value(&pool.sui_reserve);

    if (happy_reserve == 0) {
        abort E_DIVISION_BY_ZERO;
    };

    let price_per_happy = sui_reserve * 1_000_000_000 / happy_reserve; // * scaled up
    (happy_amount * price_per_happy) / 1_000_000_000 // then scale back
}


public entry fun swap_happy_to_sui(
    pool: &mut LiquidityPool,
    mut happy_payment: Coin<SUI_CONTRACT_TOKEN_SPLIT>,
    value: u64,
    ctx: &mut TxContext
) {
    // Step 1: Split the user's payment
    let new_happy = coin::split(&mut happy_payment, value, ctx);

    // Step 2: Calculate how much SUI the user should receive
    let sui_amt = calculate_sui_price(pool, value);

    // Step 3: Check if the pool has enough SUI to pay
    if (sui_amt > coin::value(&pool.sui_reserve)) {
        abort E_INSUFFICIENT_BALANCE;
    };

    // Step 4: Split the required SUI from the pool
    let new_sui = coin::split(&mut pool.sui_reserve, sui_amt, ctx);

    // Step 5: Join the user's HAPPY into the pool
    coin::join(&mut pool.happy_reserve, new_happy);

    // Step 6: Transfer the SUI to the user
    public_transfer(new_sui, sender(ctx));

    // Step 7: Return leftover HAPPY (if any)
    public_transfer(happy_payment, sender(ctx));
}
}