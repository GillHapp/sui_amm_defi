module sui_contract_token_split::lp_token {
    use std::option::none;
    use sui::coin::{Self, TreasuryCap};
    use sui::object::{UID, new};
    use sui::tx_context::TxContext;
    use sui::transfer::public_transfer;

    public struct LP_TOKEN has drop {}

    public struct LPMinterCap has key, store {
        id: UID,
        treasury_cap: TreasuryCap<LP_TOKEN>,
    }
    
    /// Initializes the LP token and returns both the LPMinterCap and the metadata object.
    fun init(witness: LP_TOKEN, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness,
            9,
            b"LP",
            b"Liquidity Provider Token",
            b"Token for LP Share Tracking",
            none(),
            ctx,
        );
        // Freeze metadata and mint initial tokens to sender
        let mut minter_cap = LPMinterCap {
            id: new(ctx),
            treasury_cap,
        };
        let initial_supply = 100000000000000;
        let new_coin = coin::mint(&mut minter_cap.treasury_cap, initial_supply, ctx);
        public_transfer(new_coin, tx_context::sender(ctx));
        public_transfer(minter_cap, tx_context::sender(ctx));
        public_transfer(metadata, tx_context::sender(ctx));
    }


    public entry fun mint(
        minter_cap: &mut LPMinterCap,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let new_coin = coin::mint(&mut minter_cap.treasury_cap, amount, ctx);
        public_transfer(new_coin, recipient);
    }
}
