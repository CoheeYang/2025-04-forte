

# [H-1] addition for two medium-size mantissas numbers will have decimal loss when quantity difference is greater than 38

## Root Cause














# [H-1] : add() function would have decimal loss for `sdiv()`


## Root Cause
https://github.com/code-423n4/2025-04-forte/blob/4d6694f68e80543885da78666e38c0dc7052d992/src/Float128.sol#L85-L88


In `add()` function, `sdiv()` is widely used to adjust mantissa to carry out the operation for `a` and `b`. But this would lead to potential risk of decimal loss in some cases. 

For example, L85-L88 from the code would adjust the bMan by dividing 10^adj when `adj` is not negative. 

```solidity
                    if iszero(neg) {//adj is positive or zero
                        bMan := sdiv(bMan, exp(BASE, adj))// bMan/10^adj
                        aMan := mul(aMan, BASE_TO_THE_MAX_DIGITS_M)//aMna * 10e38
                    }
```

To get into L85-L88, the following conditions are required:
1. **`a` and `b` are both medium-size mantissas.**
- This means that aMan and bMan, according to the normalization in `toPackedFloat()`, is a 38 digit from `MIN_M_DIGIT_NUMBER(10^37)` to `MAX_L_DIGIT_NUMBER(10^38 -1)`.

2. **adj is non-negative.** 
-  In this sitatuation `adj = aExp - bExp - 38`, then `aExp-bExp>=38` should hold

Think about the following situtation:
- `a = 1`, then `aMan = 10^37`,`aExp = -37`
- `b = 1e-38`then `bMan = 10^37`,`bExp = -75`

There would be decimal loss in this situation 如果aE-bE> 75 就可能出现decimal loss，但是这种情况会在toPack中被允许吗？



# 
现在的问题是，
为什么1+出现了loss
而 -1 + b没出现



Think about the following situtation:
- `a = 1`, then `aMan = 10^37`,`aExp = -37`
- `b = 1e-38`then `bMan = 10^37`,`bExp = -75`