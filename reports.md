

# [H-1] addition for two medium-size mantissas numbers will have decimal loss when quantity difference is greater than 38



## Basic Context
In `add(packedFloat a, packedFloat b)` function, the exponent quantity of `a` and `b` might be different. 

In order to add `aMan` and `bMan` properly, generally one would compare  `aExp` and `bExp`, and multiply the mantissa with smaller exponent by exponent difference(eg.`bMan x 10^(aExp-bExp)` where aExp>bExp).

But `Float128::add()` function multiplies both medium-size mantissa by 10^38 and then make the mantissa with smaller exponent divde by 10^(exponent difference) to handle potential substraction situation.

For example, both `a` and `b` have medium-size mantissa, if `aExp>bExp `, then `aMan=aMan x 10^38`, `bMan= bMan x 10^38 / 10^(aExp-bExp)`.After this calibration process, add two mantissa to get the result.

And after addition process, the result would be normalized, which divides the result by 10^38 if the result is still a medium-size one.

**But this is where things goes wrong**

## Root Cause
https://github.com/code-423n4/2025-04-forte/blob/4d6694f68e80543885da78666e38c0dc7052d992/src/Float128.sol#L224-L227


During the process of normalization for the final result, the addition branch has the following logic:
```solidity
                    if _isM {
                        addition := div(addition, BASE_TO_THE_MAX_DIGITS_M)// addition/10^38
                        r := add(r, shl(EXPONENT_BIT, MAX_DIGITS_M))//
                    }
```
For illustration purpose, let's assume aExp is larger. This intends to normalize the addition result. But this would lead to potential decimal loss as long as `aExp-bExp > 38` 

Because `addition= aMan x 10^38 + bMan x 10^38 / 10^(aExp-bExp)`, and `addition/10^38 = aMan + bMan/10^(aExp-bExp)`.

`bMan` is a 38-digit number between `[10^37 , 10^38-1]`. Thus, if `aExp-bExp>38`, bMan/10^(aExp-bExp) is always less than 1

Moreover, `aExp-bExp> 38` always holds if `adj>0`, because `adj= aExp -38 - bExp` (see [L77-L84](https://github.com/code-423n4/2025-04-forte/blob/4d6694f68e80543885da78666e38c0dc7052d992/src/Float128.sol#L77-L84))




## PoC
Try the following code, the following code shows that `(a+b)+c != a+(b+c)` due to this issue.

This decimal loss occurs only when normal addition process. And this issue dispears when subtraction or large-size mantissa are involved


```solidity
/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/Float128.sol";

contract add is Test {
    using Float128 for packedFloat;
    event log(string,int,string,int);

    /// as long as a and b are medium-size mantissa and aExp-bExp>38, the decimal loss would occur

    int256 aMan = 1;
    int256 aExp = 10;//change this number to 20, `a` would be considered as large-size mantissa, the assertion would hold

    int256 bMan = 1;
    int256 bExp = -28;
    
    int256 cMan = -1;//subtraction exits, c+b does not have decimal loss
    int256 cExp = 10;



        packedFloat a = Float128.toPackedFloat(aMan, aExp);
        packedFloat b = Float128.toPackedFloat(bMan, bExp);
        packedFloat c = Float128.toPackedFloat(cMan, cExp);
        //(a+b)+c
        packedFloat a_b = Float128.add(a, b);
        packedFloat a_b_c = Float128.add(a_b, c);
        
        //a+(b+c)
        packedFloat b_c = Float128.add(b, c);
        packedFloat b_c_a = Float128.add(a, b_c);

    function test_poc_add() public {
        
        (int aMan_dec,int aExp_dec) = Float128.decode(a);
        (int bMan_dec,int bExp_dec) = Float128.decode(b);
        (int cMan_dec,int cExp_dec) = Float128.decode(c);
        (int a_bMan_dec,int a_bExp_dec) = Float128.decode(a_b);
        (int b_cMan_dec,int b_cExp_dec) = Float128.decode(b_c);
        (int a_b_cMan_dec,int a_b_cExp_dec) = Float128.decode(a_b_c);
        (int b_c_aMan_dec,int b_c_aExp_dec) = Float128.decode(b_c_a);
        
        emit log("aMan",aMan_dec,"aExp",aExp_dec);
        emit log("bMan",bMan_dec,"bExp",bExp_dec);
        emit log("cMan",cMan_dec,"cExp",cExp_dec);

        emit log("a_bMan",a_bMan_dec,"a_bExp",a_bExp_dec);
        emit log("b_cMan",b_cMan_dec,"b_cExp",b_cExp_dec);

        emit log("a_b_c_Man",a_b_cMan_dec,"a_b_cExp",a_b_cExp_dec);
        emit log("b_c_a_Man",b_c_aMan_dec,"b_c_aExp",b_c_aExp_dec);


        assert(Float128.eq(a_b_c, b_c_a));  


    }



}

```
This is the test result:

```bash
Ran 1 test for test/PoC/PoC_Add.t.sol:add
[FAIL: panic: assertion failed (0x01)] test_poc_add() (gas: 37250)
Traces:
  [37250] add::test_poc_add()
    ├─ emit log(: "aMan", : 10000000000000000000000000000000000000 [1e37], : "aExp", : -27)
    ├─ emit log(: "bMan", : 10000000000000000000000000000000000000 [1e37], : "bExp", : -65)
    ├─ emit log(: "cMan", : -10000000000000000000000000000000000000 [-1e37], : "cExp", : -27)
    ├─ emit log(: "a_bMan", : 10000000000000000000000000000000000000 [1e37], : "a_bExp", : -27)
    ├─ emit log(: "b_cMan", : -99999999999999999999999999999999999999 [-9.999e37], : "b_cExp", : -28)
    ├─ emit log(: "a_b_c_Man", : 0, : "a_b_cExp", : -8192)
    ├─ emit log(: "b_c_a_Man", : 10000000000000000000000000000000000000 [1e37], : "b_c_aExp", : -65)
    └─ ← [Revert] panic: assertion failed (0x01)

Suite result: FAILED. 0 passed; 1 failed; 0 skipped; finished in 889.03µs (163.29µs CPU time)

Ran 1 test suite in 3.59s (889.03µs CPU time): 0 tests passed, 1 failed, 0 skipped (1 total tests)
```

if you change `aExp` from 10 to 20, the test will pass

```bash
[PASS] test_poc_add() (gas: 37251)
Traces:
  [37251] add::test_poc_add()
    ├─ emit log(: "aMan", : 100000000000000000000000000000000000000000000000000000000000000000000000 [1e71], : "aExp", : -51)
    ├─ emit log(: "bMan", : 10000000000000000000000000000000000000 [1e37], : "bExp", : -65)
    ├─ emit log(: "cMan", : -10000000000000000000000000000000000000 [-1e37], : "cExp", : -27)
    ├─ emit log(: "a_bMan", : 100000000000000000000000000000000000000000000000100000000000000000000000 [1e71], : "a_bExp", : -51)
    ├─ emit log(: "b_cMan", : -99999999999999999999999999999999999999 [-9.999e37], : "b_cExp", : -28)
    ├─ emit log(: "a_b_c_Man", : 99999999990000000000000000000000000000 [9.999e37], : "a_b_cExp", : -18)
    ├─ emit log(: "b_c_a_Man", : 99999999990000000000000000000000000000 [9.999e37], : "b_c_aExp", : -18)
    └─ ← [Stop] 

Suite result: ok. 1 passed; 0 failed; 0 skipped; finished in 598.29µs (100.66µs CPU time)

Ran 1 test suite in 2.69s (598.29µs CPU time): 1 tests passed, 0 failed, 0 skipped (1 total tests)
```






# [L-1] : add() function would have decimal loss for `sdiv()` why not change it to `mul()`?


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






# [H-2] `hasExtraDigit` condition leads to decimal loss when converting large-size mantissa result to medium-size result
## Basic Context 
In `mul()`, the function first checks the exitence of large-size mantissa, and convert the other medium-size mantissa into large-size mantissa if large-size mantissa exits. 

Then it multiples two large-size mantissa to get the result which is converted into medium-size mantissa if the exponent less or equal to`maxExp` (In this case the flag `Loperation` is 0).

But during the multiplication stage, `aMan x bMan` might generate extra digits(eg.2x5=10,which two one digit numbers generate a two digit number).

Thus, `hasExtraDigit := gt(rMan, MAX_L_DIGIT_NUMBER)` is used to check if `rMan` is a number that has extra digit,so that we can calibrate 73 or 72 digit result back to 38 digit result properly. 

To handle 73 digits result, the `rMan` will be divided by `10^35`, and this is where decimal loss occurs.


## Root Cause 
This issue occurs only when a large-size mantissa number times a medium-size mantissa number.
```solidity
               if iszero(Loperation) {//scale down the result to 38 digits
                    if hasExtraDigit {//the result has 73 digits
                        rMan := div(rMan, BASE_TO_THE_DIGIT_DIFF_PLUS_1)//rMan/10^35，
                        rExp := add(rExp, DIGIT_DIFF_L_M_PLUS_1)//+35
                    }
```
The root cause for this issue is that `mul()` converts a medium-size mantissa into a large-size mantissa by simply timing `BASE_TO_THE_DIGIT_DIFF(10^34)` (see [L475-L482](https://github.com/code-423n4/2025-04-forte/blob/4d6694f68e80543885da78666e38c0dc7052d992/src/Float128.sol#L475-L482)) ,and adopted 10^35 to scale down the result when 73 digits exits (see [L507-L511](https://github.com/code-423n4/2025-04-forte/blob/4d6694f68e80543885da78666e38c0dc7052d992/src/Float128.sol#L507-L511)). 


And this method would erase the last one digit information if a 73-digit `rMan` has 39 valid digits and 34 zero digits resulting a decimal loss.

**For example:**

23 digits, large-size mantissa `a`:
`aMan= 50000000000000000000005` 
`aExp = 0`

16 digits, medium-size mantissa `b`:
`bMan = 2000000000000003`
`cExp = -20`

The result `rMan` before division is `100000000000000150000010000000000000015..0000` with 39 valid digits, and in 34 zero digits in the form of large-size mantissa. 

During the division process,`BASE_TO_THE_DIGIT_DIFF_PLUS_1(10^35)` can remove the last number information 5, making the result different from origin.


## Impact

This introduces potential decimal loss to defi protocal, and they cannot sense and choose to preserve large-size mantissa because scaling down process is automated and no other `mul()` function can be used.

## Recommended mitigation steps

Judge the valid digits before division, or create a `mul()` function that allow protocals to choose whether to preserves the large-size mantissa result just like `div(packedFloat a, packedFloat b, bool rL)`.
