/// Initialize the global currency container if it does not already exist.
/// Optionally accepts a starting amount (defaults to preserving the current balance).
function currency_init(_starting_amount = undefined){
    if (!variable_global_exists("CURRENCY") || !is_struct(global.CURRENCY)){
        global.CURRENCY = { money: 0 };
    } else if (!variable_struct_exists(global.CURRENCY, "money") || !is_real(global.CURRENCY.money)){
        global.CURRENCY.money = 0;
    }

    if (!is_undefined(_starting_amount)){
        var _seed_amount = max(0, floor(real(_starting_amount)));
        global.CURRENCY.money = _seed_amount;
    }

    return global.CURRENCY.money;
}

/// Return the player's current money total as an integer.
function currency_get(){
    if (!variable_global_exists("CURRENCY") || !is_struct(global.CURRENCY)) return 0;
    if (!variable_struct_exists(global.CURRENCY, "money") || !is_real(global.CURRENCY.money)) return 0;
    return max(0, floor(real(global.CURRENCY.money)));
}

/// Add the supplied amount to the player's money (negative values subtract) and return the new total.
function currency_add(_delta){
    currency_init();
    var _adjust = floor(real(_delta));
    if (_adjust == 0) return currency_get();
    var _next = currency_get() + _adjust;
    if (_next < 0) _next = 0;
    global.CURRENCY.money = _next;
    return global.CURRENCY.money;
}

/// Overwrite the player's money with an explicit amount and return the clamped value.
function currency_set(_amount){
    currency_init();
    var _target = max(0, floor(real(_amount)));
    global.CURRENCY.money = _target;
    return global.CURRENCY.money;
}
