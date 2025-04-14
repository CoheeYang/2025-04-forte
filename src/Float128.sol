// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Uint512} from "../lib/Uint512.sol";
import {packedFloat} from "./Types.sol";

/**
 * @title Floating point Library base 10 with 38 or 72 digits signed
 * @dev the library uses the type packedFloat which is a uint under the hood
 * @author Inspired by a Python proposal by @miguel-ot and refined/implemented in Solidity by @oscarsernarosero @Palmerg4
 */

library Float128 {
    uint constant MANTISSA_MASK = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    uint constant MANTISSA_SIGN_MASK = 0x1000000000000000000000000000000000000000000000000000000000000;
    uint constant MANTISSA_L_FLAG_MASK = 0x2000000000000000000000000000000000000000000000000000000000000;
    uint constant EXPONENT_MASK = 0xfffc000000000000000000000000000000000000000000000000000000000000;
    uint constant TWO_COMPLEMENT_SIGN_MASK = 0x8000000000000000000000000000000000000000000000000000000000000000;
    uint constant BASE = 10;
    uint constant ZERO_OFFSET = 8192;
    uint constant ZERO_OFFSET_MINUS_1 = 8191;
    uint constant EXPONENT_BIT = 242;
    uint constant MAX_DIGITS_M = 38;
    uint constant MAX_DIGITS_M_X_2 = 76;
    uint constant MAX_DIGITS_M_MINUS_1 = 37;
    uint constant MAX_DIGITS_M_PLUS_1 = 39;
    uint constant MAX_DIGITS_L = 72;
    uint constant MAX_DIGITS_L_MINUS_1 = 71;
    uint constant MAX_DIGITS_L_PLUS_1 = 73;
    uint constant DIGIT_DIFF_L_M = 34;
    uint constant DIGIT_DIFF_L_M_PLUS_1 = 35;
    uint constant DIGIT_DIFF_76_L_MINUS_1 = 3;
    uint constant DIGIT_DIFF_76_L = 4;
    uint constant DIGIT_DIFF_76_L_PLUS_1 = 5;
    uint constant MAX_M_DIGIT_NUMBER = 99999999999999999999999999999999999999;
    uint constant MIN_M_DIGIT_NUMBER = 10000000000000000000000000000000000000;
    uint constant MAX_L_DIGIT_NUMBER = 999999999999999999999999999999999999999999999999999999999999999999999999;
    uint constant MIN_L_DIGIT_NUMBER = 100000000000000000000000000000000000000000000000000000000000000000000000;
    uint constant BASE_TO_THE_MAX_DIGITS_L = 1000000000000000000000000000000000000000000000000000000000000000000000000;
    uint constant BASE_TO_THE_DIGIT_DIFF = 10000000000000000000000000000000000;
    uint constant BASE_TO_THE_DIGIT_DIFF_PLUS_1 = 100000000000000000000000000000000000;
    uint constant BASE_TO_THE_MAX_DIGITS_M_MINUS_1 = 10000000000000000000000000000000000000;
    uint constant BASE_TO_THE_MAX_DIGITS_M = 100000000000000000000000000000000000000;
    uint constant BASE_TO_THE_MAX_DIGITS_M_PLUS_1 = 1000000000000000000000000000000000000000;
    uint constant BASE_TO_THE_MAX_DIGITS_M_X_2 = 10000000000000000000000000000000000000000000000000000000000000000000000000000;
    uint constant BASE_TO_THE_DIFF_76_L_MINUS_1 = 1_000;
    uint constant BASE_TO_THE_DIFF_76_L = 10_000;
    uint constant BASE_TO_THE_DIFF_76_L_PLUS_1 = 100_000;
    uint constant MAX_75_DIGIT_NUMBER = 999999999999999999999999999999999999999999999999999999999999999999999999999;
    uint constant MAX_76_DIGIT_NUMBER = 9999999999999999999999999999999999999999999999999999999999999999999999999999;
    int constant MAXIMUM_EXPONENT = -18; // guarantees all results will have at least 18 decimals in the M size. Autoscales to L if necessary
    

    event checkLog(string); //by @audit

    /**
     * @dev adds 2 signed floating point numbers
     * @param a the first addend
     * @param b the second addend
     * @return r the result of a + b
     */
    function add(packedFloat a, packedFloat b) internal pure returns (packedFloat r) {
        uint addition;
        bool isSubtraction;
        bool sameExponent;
        if (packedFloat.unwrap(a) == 0) return b;
        if (packedFloat.unwrap(b) == 0) return a;
        assembly {
            //1.判断是否有大尾数
            let aL := gt(and(a, MANTISSA_L_FLAG_MASK), 0)
            let bL := gt(and(b, MANTISSA_L_FLAG_MASK), 0)
            //2. 判断是否有减法
            isSubtraction := xor(and(a, MANTISSA_SIGN_MASK), and(b, MANTISSA_SIGN_MASK))
            // we extract the exponent and mantissas for both
            //3.截断对应的信息
            let aExp := and(a, EXPONENT_MASK)
            let bExp := and(b, EXPONENT_MASK)
            let aMan := and(a, MANTISSA_MASK)
            let bMan := and(b, MANTISSA_MASK)
            if iszero(or(aL, bL)) {
                //情况1.没有大尾数
                // we add 38 digits of precision in the case of subtraction
                if gt(aExp, bExp) {
                    //情况1.1 aExp > bExp 则将b的指数上升以对其a  //（此处 aExp=0, bExp=-56）
                    //1.用中间指数r=aExp - 38
                    r := sub(aExp, shl(EXPONENT_BIT, MAX_DIGITS_M)) //左移38二进制exponent_bit(242)位。再拿aExp减去38Exp，得到rExp
                    //2.调整额度为adj = r - bExp
                    let adj := sub(shr(EXPONENT_BIT, r), shr(EXPONENT_BIT, bExp)) //移回去再减去 // adj = aExp -38 - bExp, //-75 + bExp
                    let neg := and(TWO_COMPLEMENT_SIGN_MASK, adj) //判断正负
                    if neg {
                        //负的
                        bMan := mul(bMan, exp(BASE, sub(0, adj)))
                        aMan := mul(aMan, BASE_TO_THE_MAX_DIGITS_M)
                    }
                    if iszero(neg) {
                        //正的
                        bMan := sdiv(bMan, exp(BASE, adj)) //signed div, //  （10^37 /10^adj）
                        aMan := mul(aMan, BASE_TO_THE_MAX_DIGITS_M) //aMna * 10e38
                    } //@audit 那么你们为什么要加这段呢？这段必然存在aExp-bExp>38，其实也我不用管b是不是触底，只要a和b差了这么多就会出问题
                }
                if gt(bExp, aExp) {
                    //情况1.2
                    r := sub(bExp, shl(EXPONENT_BIT, MAX_DIGITS_M))
                    let adj := sub(shr(EXPONENT_BIT, r), shr(EXPONENT_BIT, aExp))
                    let neg := and(TWO_COMPLEMENT_SIGN_MASK, adj)
                    if neg {
                        aMan := mul(aMan, exp(BASE, sub(0, adj)))
                        bMan := mul(bMan, BASE_TO_THE_MAX_DIGITS_M)
                    }
                    if iszero(neg) {
                        aMan := sdiv(aMan, exp(BASE, adj)) //bug
                        bMan := mul(bMan, BASE_TO_THE_MAX_DIGITS_M)
                    }
                }
                // if exponents are the same, we don't need to adjust the mantissas. We just set the result's exponent
                if eq(aExp, bExp) {
                    //情况1.3
                    aMan := mul(aMan, BASE_TO_THE_MAX_DIGITS_M)
                    bMan := mul(bMan, BASE_TO_THE_MAX_DIGITS_M)
                    r := sub(aExp, shl(EXPONENT_BIT, MAX_DIGITS_M))
                    sameExponent := 1
                }
            }
            if or(aL, bL) {
                //情况2.存在大尾情况
                // we make sure both of them are size L before continuing
                if iszero(aL) {
                    aMan := mul(aMan, BASE_TO_THE_DIGIT_DIFF) //aMan提10^34，38转为72位
                    aExp := sub(aExp, shl(EXPONENT_BIT, DIGIT_DIFF_L_M))
                }
                if iszero(bL) {
                    bMan := mul(bMan, BASE_TO_THE_DIGIT_DIFF)
                    bExp := sub(bExp, shl(EXPONENT_BIT, DIGIT_DIFF_L_M))
                }
                // we adjust the significant digits and set the exponent of the result
                if gt(aExp, bExp) {
                    r := sub(aExp, shl(EXPONENT_BIT, DIGIT_DIFF_76_L)) //aExp - 4
                    let adj := sub(shr(EXPONENT_BIT, r), shr(EXPONENT_BIT, bExp)) //adj = aExp - 4 - bExp
                    let neg := and(TWO_COMPLEMENT_SIGN_MASK, adj)
                    if neg {
                        bMan := mul(bMan, exp(BASE, sub(0, adj)))
                        aMan := mul(aMan, BASE_TO_THE_DIFF_76_L)
                    }
                    if iszero(neg) {
                        bMan := sdiv(bMan, exp(BASE, adj))
                        aMan := mul(aMan, BASE_TO_THE_DIFF_76_L)
                    }
                }
                if gt(bExp, aExp) {
                    r := sub(bExp, shl(EXPONENT_BIT, DIGIT_DIFF_76_L))
                    let adj := sub(shr(EXPONENT_BIT, r), shr(EXPONENT_BIT, aExp))
                    let neg := and(TWO_COMPLEMENT_SIGN_MASK, adj)
                    if neg {
                        aMan := mul(aMan, exp(BASE, sub(0, adj)))
                        bMan := mul(bMan, BASE_TO_THE_DIFF_76_L)
                    }
                    if iszero(neg) {
                        aMan := sdiv(aMan, exp(BASE, adj))
                        bMan := mul(bMan, BASE_TO_THE_DIFF_76_L)
                    }
                }
                // // if exponents are the same, we don't need to adjust the mantissas. We just set the result's exponent
                if eq(aExp, bExp) {
                    aMan := mul(aMan, BASE_TO_THE_DIFF_76_L)
                    bMan := mul(bMan, BASE_TO_THE_DIFF_76_L)
                    r := sub(aExp, shl(EXPONENT_BIT, DIGIT_DIFF_76_L))
                    sameExponent := 1
                }
            }
            // now we convert to 2's complement to carry out the operation
            //转换负号
            if and(b, MANTISSA_SIGN_MASK) {
                bMan := sub(0, bMan)
            }
            if and(a, MANTISSA_SIGN_MASK) {
                aMan := sub(0, aMan)
            }
            // now we can add/subtract
            addition := add(aMan, bMan) // 10^37 + 10^75
            // encoding the unnormalized result
            if and(TWO_COMPLEMENT_SIGN_MASK, addition) {
                r := or(r, MANTISSA_SIGN_MASK) // assign the negative sign
                addition := sub(0, addition) // convert back from 2's complement
            }
            if iszero(addition) {
                r := 0
            }
        }
        // normalization
        if (packedFloat.unwrap(r) > 0) {
            uint rExp;
            assembly {
                rExp := shr(EXPONENT_BIT, r) //r右移242
            }
            if (isSubtraction) {
                //减法
                // subtraction case can have a number of digits anywhere from 1 to 76
                // we might get a normalized result, so we only normalize if necessary
                if (
                    //需要normalization的情况
                    !((addition <= MAX_M_DIGIT_NUMBER && addition >= MIN_M_DIGIT_NUMBER) || (addition <= MAX_L_DIGIT_NUMBER && addition >= MIN_L_DIGIT_NUMBER))
                ) {
                    uint digitsMantissa = findNumberOfDigits(addition);
                    assembly {
                        let mantissaReducer := sub(digitsMantissa, MAX_DIGITS_M)
                        let isResultL := slt(MAXIMUM_EXPONENT, add(sub(rExp, ZERO_OFFSET), mantissaReducer))
                        if isResultL {
                            mantissaReducer := sub(mantissaReducer, DIGIT_DIFF_L_M)
                            r := or(r, MANTISSA_L_FLAG_MASK)
                        }
                        let negativeReducer := and(TWO_COMPLEMENT_SIGN_MASK, mantissaReducer)
                        if negativeReducer {
                            addition := mul(addition, exp(BASE, sub(0, mantissaReducer))) //this part never gets covered
                            r := sub(r, shl(EXPONENT_BIT, sub(0, mantissaReducer))) //this part never gets covered
                        }
                        if iszero(negativeReducer) {
                            addition := div(addition, exp(BASE, mantissaReducer))
                            r := add(r, shl(EXPONENT_BIT, mantissaReducer))
                        }
                    }
                } else if (
                    //this part never gets covered
                    addition >= MIN_L_DIGIT_NUMBER && //72位的最小值10^71
                    rExp < (ZERO_OFFSET - uint(MAXIMUM_EXPONENT * -1) - DIGIT_DIFF_L_M) //8192-18-34
                ) {
                    //this part never gets covered
                    assembly {
                        addition := sdiv(addition, BASE_TO_THE_DIGIT_DIFF)
                        r := add(r, shl(EXPONENT_BIT, DIGIT_DIFF_L_M))
                    }
                }
            } else {
                // addition case is simpler since it can only have 2 possibilities: same digits as its addends,
                // or + 1 digits due to an "overflow"
                assembly {
                    let isGreaterThan76Digits := gt(addition, MAX_76_DIGIT_NUMBER)
                    let maxExp := sub(sub(sub(add(ZERO_OFFSET, MAXIMUM_EXPONENT), DIGIT_DIFF_L_M), DIGIT_DIFF_76_L), isGreaterThan76Digits) // ((8192-18)-34)-4 -(1/0)
                    //判断小尾
                    let _isM := or(eq(rExp, maxExp), lt(rExp, maxExp))
                    if _isM {
                        addition := div(addition, BASE_TO_THE_MAX_DIGITS_M) //addition/10^38 bug 任意bMan小于10^38都会被无视
                        r := add(r, shl(EXPONENT_BIT, MAX_DIGITS_M)) //38左移242位，再加上r，原来是比如aExp-38，现在加回来
                    }
                    if iszero(_isM) {
                        addition := div(addition, BASE_TO_THE_DIFF_76_L)
                        r := add(r, shl(EXPONENT_BIT, DIGIT_DIFF_76_L))
                        r := add(r, MANTISSA_L_FLAG_MASK)
                    }
                    if or(gt(addition, MAX_L_DIGIT_NUMBER), and(lt(addition, MIN_L_DIGIT_NUMBER), gt(addition, MAX_M_DIGIT_NUMBER))) {
                        addition := div(addition, BASE)
                        r := add(r, shl(EXPONENT_BIT, 1))
                    }
                }
            }
            assembly {
                r := or(r, addition)
            }
        }
    }

    /**
     * @dev gets the difference between 2 signed floating point numbers
     * @param a the minuend
     * @param b the subtrahend
     * @return r the result of a - b
     * @notice this version of the function uses only the packedFloat type
     */
    function sub(packedFloat a, packedFloat b) internal pure returns (packedFloat r) {
        uint addition;
        bool isSubtraction;
        bool sameExponent;
        if (packedFloat.unwrap(a) == 0) {
            assembly {
                if gt(b, 0) {
                    b := xor(MANTISSA_SIGN_MASK, b)
                }
            }
            return b;
        }
        if (packedFloat.unwrap(b) == 0) return a;
        assembly {
            let aL := gt(and(a, MANTISSA_L_FLAG_MASK), 0)
            let bL := gt(and(b, MANTISSA_L_FLAG_MASK), 0)
            isSubtraction := eq(and(a, MANTISSA_SIGN_MASK), and(b, MANTISSA_SIGN_MASK))
            // we extract the exponent and mantissas for both
            let aExp := and(a, EXPONENT_MASK)
            let bExp := and(b, EXPONENT_MASK)
            let aMan := and(a, MANTISSA_MASK)
            let bMan := and(b, MANTISSA_MASK)
            if iszero(or(aL, bL)) {
                //情况1. 小尾
                // we add 38 digits of precision in the case of subtraction
                if gt(aExp, bExp) {
                    r := sub(aExp, shl(EXPONENT_BIT, MAX_DIGITS_M))
                    let adj := sub(shr(EXPONENT_BIT, r), shr(EXPONENT_BIT, bExp))
                    let neg := and(TWO_COMPLEMENT_SIGN_MASK, adj)
                    if neg {
                        bMan := mul(bMan, exp(BASE, sub(0, adj)))
                        aMan := mul(aMan, BASE_TO_THE_MAX_DIGITS_M)
                    }
                    if iszero(neg) {
                        bMan := sdiv(bMan, exp(BASE, adj))
                        aMan := mul(aMan, BASE_TO_THE_MAX_DIGITS_M)
                    }
                }
                if gt(bExp, aExp) {
                    r := sub(bExp, shl(EXPONENT_BIT, MAX_DIGITS_M))
                    let adj := sub(shr(EXPONENT_BIT, r), shr(EXPONENT_BIT, aExp))
                    let neg := and(TWO_COMPLEMENT_SIGN_MASK, adj)
                    if neg {
                        aMan := mul(aMan, exp(BASE, sub(0, adj)))
                        bMan := mul(bMan, BASE_TO_THE_MAX_DIGITS_M)
                    }
                    if iszero(neg) {
                        aMan := sdiv(aMan, exp(BASE, adj))
                        bMan := mul(bMan, BASE_TO_THE_MAX_DIGITS_M)
                    }
                }
                // if exponents are the same, we don't need to adjust the mantissas. We just set the result's exponent
                if eq(aExp, bExp) {
                    aMan := mul(aMan, BASE_TO_THE_MAX_DIGITS_M)
                    bMan := mul(bMan, BASE_TO_THE_MAX_DIGITS_M)
                    r := sub(aExp, shl(EXPONENT_BIT, MAX_DIGITS_M))
                    sameExponent := 1
                }
            }
            if or(aL, bL) {
                //情况2. 大尾
                // we make sure both of them are size L before continuing
                if iszero(aL) {
                    aMan := mul(aMan, BASE_TO_THE_DIGIT_DIFF)
                    aExp := sub(aExp, shl(EXPONENT_BIT, DIGIT_DIFF_L_M))
                }
                if iszero(bL) {
                    bMan := mul(bMan, BASE_TO_THE_DIGIT_DIFF)
                    bExp := sub(bExp, shl(EXPONENT_BIT, DIGIT_DIFF_L_M))
                }
                // we adjust the significant digits and set the exponent of the result
                if gt(aExp, bExp) {
                    r := sub(aExp, shl(EXPONENT_BIT, DIGIT_DIFF_76_L))
                    let adj := sub(shr(EXPONENT_BIT, r), shr(EXPONENT_BIT, bExp))
                    let neg := and(TWO_COMPLEMENT_SIGN_MASK, adj)
                    if neg {
                        bMan := mul(bMan, exp(BASE, sub(0, adj)))
                        aMan := mul(aMan, BASE_TO_THE_DIFF_76_L)
                    }
                    if iszero(neg) {
                        bMan := sdiv(bMan, exp(BASE, adj))
                        aMan := mul(aMan, BASE_TO_THE_DIFF_76_L)
                    }
                }
                if gt(bExp, aExp) {
                    r := sub(bExp, shl(EXPONENT_BIT, DIGIT_DIFF_76_L))
                    let adj := sub(shr(EXPONENT_BIT, r), shr(EXPONENT_BIT, aExp))
                    let neg := and(TWO_COMPLEMENT_SIGN_MASK, adj)
                    if neg {
                        aMan := mul(aMan, exp(BASE, sub(0, adj)))
                        bMan := mul(bMan, BASE_TO_THE_DIFF_76_L)
                    }
                    if iszero(neg) {
                        aMan := sdiv(aMan, exp(BASE, adj))
                        bMan := mul(bMan, BASE_TO_THE_DIFF_76_L)
                    }
                }
                // // if exponents are the same, we don't need to adjust the mantissas. We just set the result's exponent
                if eq(aExp, bExp) {
                    aMan := mul(aMan, BASE_TO_THE_DIFF_76_L)
                    bMan := mul(bMan, BASE_TO_THE_DIFF_76_L)
                    r := sub(aExp, shl(EXPONENT_BIT, DIGIT_DIFF_76_L))
                    sameExponent := 1
                }
            }
            // now we convert to 2's complement to carry out the operation
            if iszero(and(b, MANTISSA_SIGN_MASK)) {
                bMan := sub(0, bMan)
            }
            if and(a, MANTISSA_SIGN_MASK) {
                aMan := sub(0, aMan)
            }
            // now we can add/subtract
            addition := add(aMan, bMan)
            // encoding the unnormalized result
            if and(TWO_COMPLEMENT_SIGN_MASK, addition) {
                r := or(r, MANTISSA_SIGN_MASK) // assign the negative sign
                addition := sub(0, addition) // convert back from 2's complement
            }
            if iszero(addition) {
                r := 0
            }
        }
        // normalization
        if (packedFloat.unwrap(r) > 0) {
            //this part never gets covered
            uint rExp;
            assembly {
                rExp := shr(EXPONENT_BIT, r)
            }
            if (isSubtraction) {
                // subtraction case can have a number of digits anywhere from 1 to 76
                // we might get a normalized result, so we only normalize if necessary
                if (!((addition <= MAX_M_DIGIT_NUMBER && addition >= MIN_M_DIGIT_NUMBER) || (addition <= MAX_L_DIGIT_NUMBER && addition >= MIN_L_DIGIT_NUMBER))) {
                    uint digitsMantissa = findNumberOfDigits(addition);
                    assembly {
                        let mantissaReducer := sub(digitsMantissa, MAX_DIGITS_M)
                        let isResultL := slt(MAXIMUM_EXPONENT, add(sub(rExp, ZERO_OFFSET), mantissaReducer))
                        if isResultL {
                            mantissaReducer := sub(mantissaReducer, DIGIT_DIFF_L_M)
                            r := or(r, MANTISSA_L_FLAG_MASK)
                        }
                        let negativeReducer := and(TWO_COMPLEMENT_SIGN_MASK, mantissaReducer)
                        if negativeReducer {
                            addition := mul(addition, exp(BASE, sub(0, mantissaReducer)))
                            r := sub(r, shl(EXPONENT_BIT, sub(0, mantissaReducer)))
                        }
                        if iszero(negativeReducer) {
                            addition := div(addition, exp(BASE, mantissaReducer))
                            r := add(r, shl(EXPONENT_BIT, mantissaReducer))
                        }
                    }
                } else if (addition >= MIN_L_DIGIT_NUMBER && rExp < (ZERO_OFFSET - uint(MAXIMUM_EXPONENT * -1) - DIGIT_DIFF_L_M)) {
                    assembly {
                        addition := sdiv(addition, BASE_TO_THE_DIGIT_DIFF)
                        r := add(r, shl(EXPONENT_BIT, DIGIT_DIFF_L_M))
                    }
                }
            } else {
                // addition case is simpler since it can only have 2 possibilities: same digits as its addends,
                // or + 1 digits due to an "overflow"
                assembly {
                    let isGreaterThan76Digits := gt(addition, MAX_76_DIGIT_NUMBER)
                    let maxExp := sub(sub(sub(add(ZERO_OFFSET, MAXIMUM_EXPONENT), DIGIT_DIFF_L_M), DIGIT_DIFF_76_L), isGreaterThan76Digits)
                    let _isM := or(eq(rExp, maxExp), lt(rExp, maxExp))
                    if _isM {
                        addition := div(addition, BASE_TO_THE_MAX_DIGITS_M)
                        r := add(r, shl(EXPONENT_BIT, MAX_DIGITS_M))
                    }
                    if iszero(_isM) {
                        addition := div(addition, BASE_TO_THE_DIFF_76_L)
                        r := add(r, shl(EXPONENT_BIT, DIGIT_DIFF_76_L))
                        r := add(r, MANTISSA_L_FLAG_MASK)
                    }
                    if or(gt(addition, MAX_L_DIGIT_NUMBER), and(lt(addition, MIN_L_DIGIT_NUMBER), gt(addition, MAX_M_DIGIT_NUMBER))) {
                        addition := div(addition, BASE)
                        r := add(r, shl(EXPONENT_BIT, 1))
                    }
                }
            }
            assembly {
                r := or(r, addition)
            }
   
        }

    }

    /**
     * @dev gets the product of 2 signed floating point numbers
     * @param a the multiplicand
     * @param b the multiplier
     * @return r the result of a * b
     */
    function mul(packedFloat a, packedFloat b) internal pure returns (packedFloat r) {
        uint rMan;
        uint rExp;
        uint r0;
        uint r1;
        bool Loperation;
        if (packedFloat.unwrap(a) == 0 || packedFloat.unwrap(b) == 0) return packedFloat.wrap(0);
        assembly {
            let aL := gt(and(a, MANTISSA_L_FLAG_MASK), 0)
            let bL := gt(and(b, MANTISSA_L_FLAG_MASK), 0)
            Loperation := or(aL, bL)
            // we extract the exponent and mantissas for both
            let aExp := and(a, EXPONENT_MASK)
            let bExp := and(b, EXPONENT_MASK)
            let aMan := and(a, MANTISSA_MASK)
            let bMan := and(b, MANTISSA_MASK)

            if Loperation {//情况1.大尾存在，进行大尾数运算
                // we make sure both of them are size L before continuing
                //小尾改大尾
                if iszero(aL) {
                    aMan := mul(aMan, BASE_TO_THE_DIGIT_DIFF)
                    aExp := sub(aExp, shl(EXPONENT_BIT, DIGIT_DIFF_L_M))
                }
                if iszero(bL) {
                    bMan := mul(bMan, BASE_TO_THE_DIGIT_DIFF)//x10^34, 10^37 -> 10^71 
                    bExp := sub(bExp, shl(EXPONENT_BIT, DIGIT_DIFF_L_M))//+34
                }
                rExp := sub(add(shr(EXPONENT_BIT, aExp), shr(EXPONENT_BIT, bExp)), ZERO_OFFSET)//幂数相加  aExp+bExp -8192=原(aExp+bExp)+8192;打包的Exp中加了8192以区分正负
                let mm := mulmod(aMan, bMan, not(0))//`(aMan * bMan) % (2^256 - 1)`，取乘积的模，防止有乘法溢出导致的问题，即256位转512位
                r0 := mul(aMan, bMan)
                r1 := sub(sub(mm, r0), lt(mm, r0))//调整高位以正确处理溢出， mm-r0-(mm<r0?1:0)
                //aMan*bMan = r0 + r1*2^256
            }
            if iszero(Loperation) {//情况2.两个小尾运算
                rMan := mul(aMan, bMan)//尾数相乘
                rExp := sub(add(shr(EXPONENT_BIT, aExp), shr(EXPONENT_BIT, bExp)), ZERO_OFFSET)//幂数相加  aExp+bExp -8192=原(aExp+bExp)+8192;打包的Exp中加了8192以区分正负
            }
        }
        if (Loperation) {//继续情况1，大尾数结果处理
            // MIN_L_DIGIT_NUMBER is equal to BASE ** (MAX_L_DIGITS - 1). 10^71
            // We avoid losing the lsd this way, but we could get 1 extra digit
            rMan = Uint512.div512x256(r0, r1, MIN_L_DIGIT_NUMBER);
            assembly {
                rExp := add(rExp, MAX_DIGITS_L_MINUS_1)//之前两个大尾相加多了个71，现在补回一个，rExp +71
                let hasExtraDigit := gt(rMan, MAX_L_DIGIT_NUMBER)// 大于10^72 -1,72位的999，//验证rMan是否有超过72位
                let maxExp := sub(sub(add(ZERO_OFFSET, MAXIMUM_EXPONENT), DIGIT_DIFF_L_M), hasExtraDigit)//8192-18-34-hasExtraDigit
                Loperation := gt(rExp, maxExp)//现在的rExp>-(52+hasExtraDigit)?
                // if not, we then know that it is a 2k-1-digit number
                if and(Loperation, hasExtraDigit) {//还是大尾，但是多一位，需要处理掉
                    rMan := div(rMan, BASE)
                    rExp := add(rExp, 1)
                }
                if iszero(Loperation) {//大转小，bug 存在精度丢失的情况，用户无法感知这一问题，可能出现潜在问题
                    if hasExtraDigit {//
                        rMan := div(rMan, BASE_TO_THE_DIGIT_DIFF_PLUS_1)//rMan/10^35，多除了一位，多丢失一位精度
                        rExp := add(rExp, DIGIT_DIFF_L_M_PLUS_1)//+35
                    }
                    if iszero(hasExtraDigit) {
                        rMan := div(rMan, BASE_TO_THE_DIGIT_DIFF)// rMan/10^34
                        rExp := add(rExp, DIGIT_DIFF_L_M)
                    }
                }
            }
        } else {//继续情况2，小尾数结果处理
            assembly {
                // multiplication between 2 numbers with k digits can result in a number between 2*k - 1 and 2*k digits
                // we check first if rMan is a 2k-digit number
                let is76digit := gt(rMan, MAX_75_DIGIT_NUMBER) // 75位的999， rMan>10^75 -1 ?
                let maxExp := add(sub(sub(add(ZERO_OFFSET, MAXIMUM_EXPONENT), DIGIT_DIFF_L_M), DIGIT_DIFF_76_L), iszero(is76digit))//8192-18-34-4
                Loperation := gt(rExp, maxExp)//原(aExp+bExp)+8192 > 8192-18-34-4? // aExp+bExp > -56+is76 
                if is76digit {//1--76位数
                    if Loperation {
                        rMan := div(rMan, BASE_TO_THE_DIFF_76_L)//10_000
                        rExp := add(rExp, DIGIT_DIFF_76_L)//76，两倍38与大尾储存72位的差距，4
                    }
                    if iszero(Loperation) {
                        rMan := div(rMan, BASE_TO_THE_MAX_DIGITS_M)//10^38 为什么是个38，因为这里是76位的情况，除以38还原38位小尾数
                        rExp := add(rExp, MAX_DIGITS_M)//38位数
                    }
                }
                // if not, we then know that it is a 2k-1-digit number
                if iszero(is76digit) {//2--非76位，只有是75位
                    if Loperation {//此时aExp+bExp > -56+is76 = -56+0
                        rMan := div(rMan, BASE_TO_THE_DIFF_76_L_MINUS_1)//rMan/1_000 
                        rExp := add(rExp, DIGIT_DIFF_76_L_MINUS_1)//rExp + 3
                    }
                    if iszero(Loperation) {
                        rMan := div(rMan, BASE_TO_THE_MAX_DIGITS_M_MINUS_1)//10^37
                        rExp := add(rExp, MAX_DIGITS_M_MINUS_1)//10^37
                    }
                }
            }
        }
        assembly {//结果拼装
            //1.a,b的符号拿出来看，xor判断如果有不同则输出1，负数
            r := or(xor(and(a, MANTISSA_SIGN_MASK), and(b, MANTISSA_SIGN_MASK)), or(rMan, shl(EXPONENT_BIT, rExp)))//rExp左移，写入rMan信息和负号信息。

            if Loperation {
                r := or(r, MANTISSA_L_FLAG_MASK)
            }
        }
    }

    /**
     * @dev gets the quotient of 2 signed floating point numbers
     * @param a the numerator
     * @param b the denominator
     * @return r the result of a / b
     */
    function div(packedFloat a, packedFloat b) internal pure returns (packedFloat r) {
        r = div(a, b, false);
    }

    /**
     * @dev gets the quotient of 2 signed floating point numbers which results in a large mantissa (72 digits) for better precision
     * @param a the numerator
     * @param b the denominator
     * @return r the result of a / b
     */
    function divL(packedFloat a, packedFloat b) internal pure returns (packedFloat r) {
        r = div(a, b, true);
    }

    /**
     * @dev gets the remainder of 2 signed floating point numbers
     * @param a the numerator
     * @param b the denominator
     * @param rL Large mantissa flag for the result. If true, the result will be force to use 72 digits for the mansitssa
     * @return r the result of a / b
     */
    function div(packedFloat a, packedFloat b, bool rL) internal pure returns (packedFloat r) {
        assembly {//检查分母0值
            if eq(and(b, MANTISSA_MASK), 0) {
                let ptr := mload(0x40) // Get free memory pointer
                mstore(ptr, 0x08c379a000000000000000000000000000000000000000000000000000000000) // Selector for method Error(string)
                mstore(add(ptr, 0x04), 0x20) // String offset
                mstore(add(ptr, 0x24), 26) // Revert reason length
                mstore(add(ptr, 0x44), "float128: division by zero")
                revert(ptr, 0x64) // Revert data length is 4 bytes for selector and 3 slots of 0x20 bytes
            }
        }
        if (packedFloat.unwrap(a) == 0) return a;
        uint rMan;
        uint rExp;
        uint a0;
        uint a1;
        uint aMan;
        uint aExp;
        uint bMan;
        uint bExp;
        bool Loperation;
        assembly {
            let aL := gt(and(a, MANTISSA_L_FLAG_MASK), 0)
            let bL := gt(and(b, MANTISSA_L_FLAG_MASK), 0)
            // if a is zero then the result will be zero
            aMan := and(a, MANTISSA_MASK)
            aExp := shr(EXPONENT_BIT, and(a, EXPONENT_MASK))
            bMan := and(b, MANTISSA_MASK)
            bExp := shr(EXPONENT_BIT, and(b, EXPONENT_MASK))
            Loperation := or(
                or(rL, or(aL, bL)),//判断large 尾数
                // we add 1 to the calculation because division could result in an extra digit which will increase
                // the value of the exponent hence potentially violating maximum exponent
                sgt(add(sub(sub(sub(aExp, ZERO_OFFSET), MAX_DIGITS_M), sub(bExp, ZERO_OFFSET)), 1), MAXIMUM_EXPONENT)// aExp-8192-38-(bExp-8192) +1 > -18 ?
            )

            if Loperation {//情况1.大尾计算
                ////1.小补大尾
                if iszero(aL) {
                    aMan := mul(aMan, BASE_TO_THE_DIGIT_DIFF)
                    aExp := sub(aExp, DIGIT_DIFF_L_M)
                }
                if iszero(bL) {
                    bMan := mul(bMan, BASE_TO_THE_DIGIT_DIFF)
                    bExp := sub(bExp, DIGIT_DIFF_L_M)
                }
                //2.和乘法一样，除出来的数可能溢出
                let mm := mulmod(aMan, BASE_TO_THE_MAX_DIGITS_L, not(0))
                a0 := mul(aMan, BASE_TO_THE_MAX_DIGITS_L)
                a1 := sub(sub(mm, a0), lt(mm, a0))
                aExp := sub(aExp, MAX_DIGITS_L)//aExp -72，去掉一个72
            }
            if iszero(Loperation) {//情况2.小尾计算
                // we add 38 more digits of precision
                aMan := mul(aMan, BASE_TO_THE_MAX_DIGITS_M)
                aExp := sub(aExp, MAX_DIGITS_M)
            }
        }
        if (Loperation) {//继续情况1.计算大尾结果
            rMan = Uint512.div512x256(a0, a1, bMan);
            unchecked {
                rExp = (aExp + ZERO_OFFSET) - bExp;
            }
        } else {//继续情况1.计算小尾结果
            assembly {
                rMan := div(aMan, bMan)
                rExp := sub(add(aExp, ZERO_OFFSET), bExp)
            }
        }
        assembly {
            if iszero(Loperation) {
                let hasExtraDigit := gt(rMan, MAX_M_DIGIT_NUMBER)
                if hasExtraDigit {
                    // we need to truncate the last digit
                    rExp := add(rExp, 1)
                    rMan := div(rMan, BASE)
                }
            }
            if Loperation {//和乘法一样判断是否有多余的digit，但是这里不会产生问题，因为最终结果是72位的，没有强行变成38位，除非两个非常复杂的72位相除，可以写一个Low
                let hasExtraDigit := gt(rMan, MAX_L_DIGIT_NUMBER)
                let maxExp := sub(sub(add(ZERO_OFFSET, MAXIMUM_EXPONENT), DIGIT_DIFF_L_M), hasExtraDigit)
                Loperation := or(gt(rExp, maxExp), rL)
                if and(Loperation, hasExtraDigit) {
                    // we need to truncate the last digit
                    rExp := add(rExp, 1)
                    rMan := div(rMan, BASE)
                }
                if iszero(Loperation) {
                    if hasExtraDigit {
                        rExp := add(rExp, DIGIT_DIFF_L_M_PLUS_1)
                        rMan := div(rMan, BASE_TO_THE_DIGIT_DIFF_PLUS_1)
                    }
                    if iszero(hasExtraDigit) {
                        rExp := add(rExp, DIGIT_DIFF_L_M)
                        rMan := div(rMan, BASE_TO_THE_DIGIT_DIFF)
                    }
                }
            }
            ///最后组装结果
            r := or(xor(and(a, MANTISSA_SIGN_MASK), and(b, MANTISSA_SIGN_MASK)), or(rMan, shl(EXPONENT_BIT, rExp)))
            if Loperation {
                r := or(r, MANTISSA_L_FLAG_MASK)
            }
        }
    }

    /**
     * @dev get the square root of a signed floating point
     * @notice only positive numbers can have their square root calculated through this function
     * @param a the numerator to get the square root of
     * @return r the result of √a
     */
    function sqrt(packedFloat a) public/*internal*/ pure returns (packedFloat r) {
        uint s;
        int aExp;
        uint x;
        uint aMan;
        uint256 roundedDownResult;
        bool aL;
        // bool touched; //by @audit 
        assembly {
            if and(a, MANTISSA_SIGN_MASK) {//负数Revert
                let ptr := mload(0x40) // Get free memory pointer
                mstore(ptr, 0x08c379a000000000000000000000000000000000000000000000000000000000) // Selector for method Error(string)
                mstore(add(ptr, 0x04), 0x20) // String offset
                mstore(add(ptr, 0x24), 32) // Revert reason length
                mstore(add(ptr, 0x44), "float128: squareroot of negative")
                revert(ptr, 0x64) // Revert data length is 4 bytes for selector and 3 slots of 0x20 bytes
            }
            if iszero(a) {//0停止，截断r 默认为0
                stop()
            }
            aL := gt(and(a, MANTISSA_L_FLAG_MASK), 0)
            aMan := and(a, MANTISSA_MASK)
            aExp := shr(EXPONENT_BIT, and(a, EXPONENT_MASK))
        }
        //大尾 且 aExp> 8192 - (34-1)  ||  小尾 且 aExp > 8192 - (38/2-1)
        //即大尾且 aExp>-33  或者小尾且 aExp > -18
        if ((aL && aExp > int(ZERO_OFFSET) - int(DIGIT_DIFF_L_M - 1)) || (!aL && aExp > int(ZERO_OFFSET) - int(MAX_DIGITS_M / 2 - 1))) {//情况1.针对大位数且实际数值在38位以上/ 小尾且实际数值在19位以上的大数字情况
            if (!aL) {//小尾数，补齐补成大尾
                aMan *= BASE_TO_THE_DIGIT_DIFF;
                aExp -= int(DIGIT_DIFF_L_M);
            }

            aExp -= int(ZERO_OFFSET);
            if (aExp % 2 != 0) {//不是2次方的情况
                aMan *= BASE;//位数进一位，后面指数减一位
                --aExp;
                // touched=true; //by @audit 
            }
            ///计算
            (uint a0, uint a1) = Uint512.mul256x256(aMan, BASE_TO_THE_MAX_DIGITS_L);//aMan x 10^72
            uint rMan = Uint512.sqrt512(a0, a1);
            int rExp = aExp - int(MAX_DIGITS_L);//aExp -72
            bool Lresult = true;
            unchecked {
                if (rMan > MAX_L_DIGIT_NUMBER) {//结果大于最大10^72 -1 降位
                    rMan /= BASE;
                    ++rExp; //@audit 你这上面在a上除以2之后，又加上一个1什么意思？那不是没搞成吗 
                    //assert(!touched);//by @audit 
                }
                rExp = (rExp) / 2;
                if (rExp <= MAXIMUM_EXPONENT - int(DIGIT_DIFF_L_M)) {//rExp太小，rExp<-18-34 
                    rMan /= BASE_TO_THE_DIGIT_DIFF;//rMan 减少34位
                    rExp += int(DIGIT_DIFF_L_M);//
                    Lresult = false;
                }
                rExp += int(ZERO_OFFSET);
            }
            assembly {
                r := or(or(shl(EXPONENT_BIT, rExp), rMan), mul(Lresult, MANTISSA_L_FLAG_MASK))
            }
        }
        // we need the exponent to be even so we can calculate the square root correctly
        else {//情况2.小数字情况
            assembly {
                if iszero(mod(aExp, 2)) {
                    if aL {
                        x := mul(aMan, BASE_TO_THE_DIFF_76_L)
                        aExp := sub(aExp, DIGIT_DIFF_76_L)
                    }
                    if iszero(aL) {
                        x := mul(aMan, BASE_TO_THE_MAX_DIGITS_M)
                        aExp := sub(aExp, MAX_DIGITS_M)
                    }
                }
                if mod(aExp, 2) {
                    if aL {
                        x := mul(aMan, BASE_TO_THE_DIFF_76_L_PLUS_1)
                        aExp := sub(aExp, DIGIT_DIFF_76_L_PLUS_1)
                    }
                    if iszero(aL) {
                        x := mul(aMan, BASE_TO_THE_MAX_DIGITS_M_PLUS_1)
                        aExp := sub(aExp, MAX_DIGITS_M_PLUS_1)
                    }
                }
                s := 1

                let xAux := x

                let cmp := or(gt(xAux, 0x100000000000000000000000000000000), eq(xAux, 0x100000000000000000000000000000000))
                xAux := sar(mul(cmp, 128), xAux)
                s := shl(mul(cmp, 64), s)

                cmp := or(gt(xAux, 0x10000000000000000), eq(xAux, 0x10000000000000000))
                xAux := sar(mul(cmp, 64), xAux)
                s := shl(mul(cmp, 32), s)

                cmp := or(gt(xAux, 0x100000000), eq(xAux, 0x100000000))
                xAux := sar(mul(cmp, 32), xAux)
                s := shl(mul(cmp, 16), s)

                cmp := or(gt(xAux, 0x10000), eq(xAux, 0x10000))
                xAux := sar(mul(cmp, 16), xAux)
                s := shl(mul(cmp, 8), s)

                cmp := or(gt(xAux, 0x100), eq(xAux, 0x100))
                xAux := sar(mul(cmp, 8), xAux)
                s := shl(mul(cmp, 4), s)

                cmp := or(gt(xAux, 0x10), eq(xAux, 0x10))
                xAux := sar(mul(cmp, 4), xAux)
                s := shl(mul(cmp, 2), s)

                s := shl(mul(or(gt(xAux, 0x8), eq(xAux, 0x8)), 2), s)

                s := shr(1, add(div(x, s), s))
                s := shr(1, add(div(x, s), s))
                s := shr(1, add(div(x, s), s))
                s := shr(1, add(div(x, s), s))
                s := shr(1, add(div(x, s), s))
                s := shr(1, add(div(x, s), s))
                s := shr(1, add(div(x, s), s))

                roundedDownResult := div(x, s)
                if or(gt(s, roundedDownResult), eq(s, roundedDownResult)) {
                    s := roundedDownResult
                }

                // exponent should now be half of what it was
                aExp := add(div(sub(aExp, ZERO_OFFSET), 2), ZERO_OFFSET)
                // if we have extra digits, we know it comes from the extra digit to make the exponent even
                if gt(s, MAX_M_DIGIT_NUMBER) {
                    aExp := add(aExp, 1)
                    s := div(s, BASE)
                }
                // final encoding
                r := or(shl(EXPONENT_BIT, aExp), s)
            }
        }
    }

    /**
     * @dev performs a less than comparison
     * @param a the first term
     * @param b the second term
     * @return retVal the result of a < b
     */
    function lt(packedFloat a, packedFloat b) internal pure returns (bool retVal) {
        if (packedFloat.unwrap(a) == packedFloat.unwrap(b)) return false;
        assembly {
            let aL := gt(and(a, MANTISSA_L_FLAG_MASK), 0)
            let bL := gt(and(b, MANTISSA_L_FLAG_MASK), 0)
            let aNeg := gt(and(a, MANTISSA_SIGN_MASK), 0)
            let bNeg := gt(and(b, MANTISSA_SIGN_MASK), 0)
            let isAZero := iszero(a)
            let isBZero := iszero(b)
            let zeroFound := or(isAZero, isBZero)
            if zeroFound {//情况1. 有0值
                //如果另外一个值为负，则返回true
                if or(and(isAZero, iszero(bNeg)), and(isBZero, aNeg)) {
                    retVal := true
                }//不要其他内容了，reVal自动默认false
            }
            if iszero(zeroFound) {//情况2. 没有0值
                let aExp := and(a, EXPONENT_MASK)
                let bExp := and(b, EXPONENT_MASK)
                let aMan := and(a, MANTISSA_MASK)
                let bMan := and(b, MANTISSA_MASK)
                if iszero(aL) {//a小转大
                    aMan := mul(aMan, BASE_TO_THE_DIGIT_DIFF)
                    aExp := sub(aExp, shl(EXPONENT_BIT, DIGIT_DIFF_L_M))
                }
                if iszero(bL) {//小转大
                    bMan := mul(bMan, BASE_TO_THE_DIGIT_DIFF)
                    bExp := sub(bExp, shl(EXPONENT_BIT, DIGIT_DIFF_L_M))
                }
                if xor(aNeg, bNeg) {//a,b异号，a负则true
                    retVal := aNeg
                }
                if and(iszero(aNeg), iszero(bNeg)) {//a,b正数
                    if eq(aExp, bExp) {//同一指数，直接比较尾数
                        retVal := lt(aMan, bMan)
                    }
                    if lt(aExp, bExp) {//a的指数小于b 
                        retVal := true
                    }
                }
                if and(aNeg, bNeg) {//a,b同负号
                    if eq(aExp, bExp) {
                        retVal := gt(aMan, bMan)
                    }
                    if gt(aExp, bExp) {
                        retVal := true
                    }
                }
            }
        }
    }

    /**
     * @dev performs a less than or equals to comparison
     * @param a the first term
     * @param b the second term
     * @return retVal the result of a <= b
     */
    function le(packedFloat a, packedFloat b) internal pure returns (bool retVal) {
        if (packedFloat.unwrap(a) == packedFloat.unwrap(b)) return true;//和上面比就多了个这个
        assembly {
            let aL := gt(and(a, MANTISSA_L_FLAG_MASK), 0)
            let bL := gt(and(b, MANTISSA_L_FLAG_MASK), 0)
            let aNeg := gt(and(a, MANTISSA_SIGN_MASK), 0)
            let bNeg := gt(and(b, MANTISSA_SIGN_MASK), 0)
            let isAZero := iszero(a)
            let isBZero := iszero(b)
            let zeroFound := or(isAZero, isBZero)
            if zeroFound {
                if or(and(isAZero, iszero(bNeg)), and(isBZero, aNeg)) {
                    retVal := true
                }
            }
            if iszero(zeroFound) {
                let aExp := and(a, EXPONENT_MASK)
                let bExp := and(b, EXPONENT_MASK)
                let aMan := and(a, MANTISSA_MASK)
                let bMan := and(b, MANTISSA_MASK)
                if iszero(aL) {
                    aMan := mul(aMan, BASE_TO_THE_DIGIT_DIFF)
                    aExp := sub(aExp, shl(EXPONENT_BIT, DIGIT_DIFF_L_M))
                }
                if iszero(bL) {
                    bMan := mul(bMan, BASE_TO_THE_DIGIT_DIFF)
                    bExp := sub(bExp, shl(EXPONENT_BIT, DIGIT_DIFF_L_M))
                }
                if xor(aNeg, bNeg) {
                    retVal := aNeg
                }
                if and(iszero(aNeg), iszero(bNeg)) {
                    if eq(aExp, bExp) {
                        retVal := lt(aMan, bMan)
                    }
                    if lt(aExp, bExp) {
                        retVal := true
                    }
                }
                if and(aNeg, bNeg) {
                    if eq(aExp, bExp) {
                        retVal := gt(aMan, bMan)
                    }
                    if gt(aExp, bExp) {
                        retVal := true
                    }
                }
            }
        }
    }

    /**
     * @dev performs a greater than comparison
     * @param a the first term
     * @param b the second term
     * @return retVal the result of a > b
     */
    function gt(packedFloat a, packedFloat b) internal pure returns (bool retVal) {
        if (packedFloat.unwrap(a) == packedFloat.unwrap(b)) return false;
        assembly {
            let aL := gt(and(a, MANTISSA_L_FLAG_MASK), 0)
            let bL := gt(and(b, MANTISSA_L_FLAG_MASK), 0)
            let aNeg := gt(and(a, MANTISSA_SIGN_MASK), 0)
            let bNeg := gt(and(b, MANTISSA_SIGN_MASK), 0)
            let isAZero := iszero(a)
            let isBZero := iszero(b)
            let zeroFound := or(isAZero, isBZero)
            if zeroFound {
                if or(and(isBZero, iszero(aNeg)), and(isAZero, bNeg)) {
                    retVal := true
                }
            }
            if iszero(zeroFound) {
                let aExp := and(a, EXPONENT_MASK)
                let bExp := and(b, EXPONENT_MASK)
                let aMan := and(a, MANTISSA_MASK)
                let bMan := and(b, MANTISSA_MASK)
                if iszero(aL) {
                    aMan := mul(aMan, BASE_TO_THE_DIGIT_DIFF)
                    aExp := sub(aExp, shl(EXPONENT_BIT, DIGIT_DIFF_L_M))
                }
                if iszero(bL) {
                    bMan := mul(bMan, BASE_TO_THE_DIGIT_DIFF)
                    bExp := sub(bExp, shl(EXPONENT_BIT, DIGIT_DIFF_L_M))
                }
                if xor(aNeg, bNeg) {
                    retVal := bNeg
                }
                if and(iszero(aNeg), iszero(bNeg)) {
                    if eq(aExp, bExp) {
                        retVal := lt(bMan, aMan)
                    }
                    if lt(bExp, aExp) {
                        retVal := true
                    }
                }
                if and(aNeg, bNeg) {
                    if eq(aExp, bExp) {
                        retVal := lt(aMan, bMan)
                    }
                    if lt(aExp, bExp) {
                        retVal := true
                    }
                }
            }
        }
    }

    /**
     * @dev performs a greater than or equal to comparison
     * @param a the first term
     * @param b the second term
     * @return retVal the result of a >= b
     */
    function ge(packedFloat a, packedFloat b) internal pure returns (bool retVal) {
        if (packedFloat.unwrap(a) == packedFloat.unwrap(b)) return true;
        assembly {
            let aL := gt(and(a, MANTISSA_L_FLAG_MASK), 0)
            let bL := gt(and(b, MANTISSA_L_FLAG_MASK), 0)
            let aNeg := gt(and(a, MANTISSA_SIGN_MASK), 0)
            let bNeg := gt(and(b, MANTISSA_SIGN_MASK), 0)
            let isAZero := iszero(a)
            let isBZero := iszero(b)
            let zeroFound := or(isAZero, isBZero)
            if zeroFound {
                if or(and(isBZero, iszero(aNeg)), and(isAZero, bNeg)) {
                    retVal := true
                }
            }
            if iszero(zeroFound) {
                let aExp := and(a, EXPONENT_MASK)
                let bExp := and(b, EXPONENT_MASK)
                let aMan := and(a, MANTISSA_MASK)
                let bMan := and(b, MANTISSA_MASK)
                if iszero(aL) {
                    aMan := mul(aMan, BASE_TO_THE_DIGIT_DIFF)
                    aExp := sub(aExp, shl(EXPONENT_BIT, DIGIT_DIFF_L_M))
                }
                if iszero(bL) {
                    bMan := mul(bMan, BASE_TO_THE_DIGIT_DIFF)
                    bExp := sub(bExp, shl(EXPONENT_BIT, DIGIT_DIFF_L_M))
                }
                if xor(aNeg, bNeg) {
                    retVal := bNeg
                }
                if and(iszero(aNeg), iszero(bNeg)) {
                    if eq(aExp, bExp) {
                        retVal := lt(bMan, aMan)
                    }
                    if lt(bExp, aExp) {
                        retVal := true
                    }
                }
                if and(aNeg, bNeg) {
                    if eq(aExp, bExp) {
                        retVal := lt(aMan, bMan)
                    }
                    if lt(aExp, bExp) {
                        retVal := true
                    }
                }
            }
        }
    }

    /**
     * @dev performs an equality comparison
     * @param a the first term
     * @param b the second term
     * @return retVal the result of a == b
     */
    function eq(packedFloat a, packedFloat b) internal pure returns (bool retVal) {
        retVal = packedFloat.unwrap(a) == packedFloat.unwrap(b);
    }

    /**
     * @dev encodes a pair of signed integer values describing a floating point number into a packedFloat
     * Examples: 1234.567 can be expressed as: 123456 x 10**(-3), or 1234560 x 10**(-4), or 12345600 x 10**(-5), etc.
     * @notice the mantissa can hold a maximum of 38 or 72 digits. Any number in between or more digits will lose precision.
     * @param mantissa the integer that holds the mantissa digits (38 or 72 digits max)
     * @param exponent the exponent of the floating point number (between -8192 and +8191)
     * @return float the encoded number. This value will ocupy a single 256-bit word and will hold the normalized
     * version of the floating-point number (shifts the exponent enough times to have exactly 38 or 72 significant digits)
     */
    function toPackedFloat(int mantissa, int exponent) internal pure returns (packedFloat float) {
        uint digitsMantissa;
        uint mantissaMultiplier;
        // we start by extracting the sign of the mantissa
        if (mantissa != 0) {
            assembly {
                if and(mantissa, TWO_COMPLEMENT_SIGN_MASK) {
                    float := MANTISSA_SIGN_MASK
                    mantissa := sub(0, mantissa)
                }
            }
            // we normalize only if necessary
            if (
                //情况1：数字位数既不是38位也不是72位时
                !((mantissa <= int(MAX_M_DIGIT_NUMBER) && mantissa >= int(MIN_M_DIGIT_NUMBER)) || (mantissa <= int(MAX_L_DIGIT_NUMBER) && mantissa >= int(MIN_L_DIGIT_NUMBER)))
            ) {
                ///1e-56
                digitsMantissa = findNumberOfDigits(uint(mantissa)); //|返回1
                assembly {
                    mantissaMultiplier := sub(digitsMantissa, MAX_DIGITS_M) //减去38位 | mantissaMultiplier=38-1=37
                    let isResultL := slt(MAXIMUM_EXPONENT, add(exponent, mantissaMultiplier)) //signed less than, (-18 < 位数+指数-38)?，-18为规定的，保证在38位的情况下有18位的计算空间
                    //这意味着一个实际超过20位的数字，就会被计算为L类型
                    if isResultL {
                        mantissaMultiplier := sub(mantissaMultiplier, DIGIT_DIFF_L_M) //如果位数+指数超过范围，再减去34（减了38又减去34，共减去72）
                        float := or(float, MANTISSA_L_FLAG_MASK) //// 标记为大尾数 241位的地方变成1 @unchecked
                    }

                    exponent := add(exponent, mantissaMultiplier) //exponent加上位数差 |exponent=-37+-56
                    let negativeMultiplier := and(TWO_COMPLEMENT_SIGN_MASK, mantissaMultiplier) //判断现在的位数差是正还是负

                    if negativeMultiplier {
                        //负数，比如只有16位，减去38，还剩22位，mantissa = mantissa * 10^22 |@audit 1e-56 走这里mantissa = 1x10^37 exponent = -37+-56,算小尾数
                        mantissa := mul(mantissa, exp(BASE, sub(0, mantissaMultiplier)))
                    }
                    if iszero(negativeMultiplier) {
                        //为什么用iszero?而不是else来判断正数--因为没有else语法
                        mantissa := div(mantissa, exp(BASE, mantissaMultiplier))
                    }
                }
            } else if (
                //情况2：数字位数是38位，且exponents大于-18情况（应该转为大尾数情况了）
                (mantissa <= int(MAX_M_DIGIT_NUMBER) && mantissa >= int(MIN_M_DIGIT_NUMBER)) && exponent > MAXIMUM_EXPONENT
            ) {
                assembly {
                    mantissa := mul(mantissa, BASE_TO_THE_DIGIT_DIFF) //10^34
                    exponent := sub(exponent, DIGIT_DIFF_L_M) //exp-34
                    float := add(float, MANTISSA_L_FLAG_MASK)
                }
            } else if ((mantissa <= int(MAX_L_DIGIT_NUMBER) && mantissa >= int(MIN_L_DIGIT_NUMBER))) {
                //情况3：数字位属于大尾数72的情况
                assembly {
                    float := add(float, MANTISSA_L_FLAG_MASK)
                }
            }
            // final encoding
            assembly {
                float := or(float, or(mantissa, shl(EXPONENT_BIT, add(exponent, ZERO_OFFSET))))
            }
        }
    }

    /**
     * @dev decodes a packedFloat into its mantissa and its exponent
     * @param float the floating-point number expressed as a packedFloat to decode
     * @return mantissa the 38 mantissa digits of the floating-point number
     * @return exponent the exponent of the floating-point number
     */
    function decode(packedFloat float) internal pure returns (int mantissa, int exponent) {
        assembly {
            // exponent
            let _exp := shr(EXPONENT_BIT, float)
            if gt(ZERO_OFFSET, _exp) {
                exponent := sub(0, sub(ZERO_OFFSET, _exp))
            }
            if gt(_exp, ZERO_OFFSET_MINUS_1) {
                exponent := sub(_exp, ZERO_OFFSET)
            }
            // mantissa
            mantissa := and(float, MANTISSA_MASK)
            /// we use 2's complement for mantissa sign
            if and(float, MANTISSA_SIGN_MASK) {
                mantissa := sub(0, mantissa)
            }
        }
    }

    /**
     * @dev finds the amount of digits of a number
     * @param x the number
     * @return log the amount of digits of x
     */
    function findNumberOfDigits(uint x) internal pure returns (uint log) {
        assembly {
            if gt(x, 0) {
                if gt(x, 9999999999999999999999999999999999999999999999999999999999999999) {
                    //大于10^64 -1时，记录64位，并除以64
                    log := 64
                    x := div(x, 10000000000000000000000000000000000000000000000000000000000000000) //10^64，有65位数字 @audit fuzzing成功
                }
                if gt(x, 99999999999999999999999999999999) {
                    log := add(log, 32)
                    x := div(x, 100000000000000000000000000000000)
                }
                if gt(x, 9999999999999999) {
                    log := add(log, 16)
                    x := div(x, 10000000000000000)
                }
                if gt(x, 99999999) {
                    log := add(log, 8)
                    x := div(x, 100000000)
                }
                if gt(x, 9999) {
                    log := add(log, 4)
                    x := div(x, 10000)
                }
                if gt(x, 99) {
                    log := add(log, 2)
                    x := div(x, 100)
                }
                if gt(x, 9) {
                    log := add(log, 1)
                }
                log := add(log, 1)
            }
        }
    }
}
