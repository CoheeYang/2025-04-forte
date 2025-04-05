/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/console2.sol";
import "src/Float128.sol";
import "test/FloatUtils.sol";

//echidna test/audit/echidna.sol --contract BasicMath --config test/audit/echidna.yaml
contract BasicMath {
    using Float128 for packedFloat;
    int256 constant BOUNDS_LOW = -3000; //exponents limits for float128
    int256 constant BOUNDS_HIGH = 3000;
    int constant ZERO_OFFSET_NEG = -8192;

    uint constant MAX_M_DIGIT_NUMBER = 99999999999999999999999999999999999999;
    uint constant MIN_M_DIGIT_NUMBER = 10000000000000000000000000000000000000;
    uint constant MAX_L_DIGIT_NUMBER = 999999999999999999999999999999999999999999999999999999999999999999999999;
    uint constant MIN_L_DIGIT_NUMBER = 100000000000000000000000000000000000000000000000000000000000000000000000;

    ///////////////helpers/////////////////
    function setBounds(int aMan, int aExp, int bMan, int bExp) internal pure returns (int _aMan, int _aExp, int _bMan, int _bExp) {
        // numbers with more than 38 digits lose precision
        _aMan = bound(aMan, -99999999999999999999999999999999999999, 99999999999999999999999999999999999999);
        _aExp = bound(aExp, BOUNDS_LOW, BOUNDS_HIGH);
        _bMan = bound(bMan, -99999999999999999999999999999999999999, 99999999999999999999999999999999999999);
        _bExp = bound(bExp, BOUNDS_LOW, BOUNDS_HIGH);
    }

    function setBounds(int aMan, int aExp) internal pure returns (int _aMan, int _aExp) {
        // numbers with more than 38 digits lose precision
        _aMan = bound(aMan, -99999999999999999999999999999999999999, 99999999999999999999999999999999999999);
        _aExp = bound(aExp, BOUNDS_LOW, BOUNDS_HIGH);
    }

    function bound(int256 value, int256 low, int256 high) internal pure returns (int256) {
        if (value < low || value > high) {
            int256 range = high - low + 1;
            int256 clamped = (value - low) % (range);
            if (clamped < 0) clamped += range;
            int256 ans = low + clamped;
            return ans;
        }
        return value;
    }

    function zero_helper(int aMan, int aExp, int bMan, int bExp, int cMan, int cExp) internal pure returns (int256 _aExp, int256 _bExp, int256 _cExp) {
        //将0的指数设置为-8192
        int256[3] memory mans = [aMan, bMan, cMan];
        int256[3] memory exps = [aExp, bExp, cExp];
        for (uint i = 0; i < mans.length; i++) {
            if (mans[i] == 0) {
                exps[i] = ZERO_OFFSET_NEG;
            }
        }
        //重新赋值
        _aExp = exps[0];
        _bExp = exps[1];
        _cExp = exps[2];
    }

    event Log(string, int256, int256, int256, int256, int256, int256);
    event result(string, uint256, string, uint256);

    ///////////////tests/////////////////
    // (x + y) + z == x + (y + z)
    function test_exchange_add(int aMan, int aExp, int bMan, int bExp, int cMan, int cExp) public {
        //先定测试边界
        (aMan, aExp, bMan, bExp) = setBounds(aMan, aExp, bMan, bExp);
        (cMan, cExp) = setBounds(cMan, cExp);

        //将0的指数设置为-8192
        (aExp, bExp, cExp) = zero_helper(aMan, aExp, bMan, bExp, cMan, cExp);

        emit Log("selected numbers", aMan, aExp, bMan, bExp, cMan, cExp);

        //开始计算
        packedFloat a = Float128.toPackedFloat(aMan, aExp);
        packedFloat b = Float128.toPackedFloat(bMan, bExp);
        packedFloat c = Float128.toPackedFloat(cMan, cExp);

        // (x + y) + z== x + (y + z)
        packedFloat a_b = Float128.add(a, b);
        packedFloat a_b_c = Float128.add(a_b, c);

        packedFloat b_c = Float128.add(b, c);
        packedFloat b_c_a = Float128.add(a, b_c);

        // console.log("a_b_c.", packedFloat.unwrap(a_b_c));
        // console.log("b_c_a.", packedFloat.unwrap(b_c_a));
        emit result("a_b_c.", packedFloat.unwrap(a_b_c), "b_c_a.", packedFloat.unwrap(b_c_a));
        assert(Float128.eq(a_b_c, b_c_a));
    }

    // (x + y) == (y + x)
    function test_simple_exchange_add(int aMan, int aExp, int bMan, int bExp) public {
        //先定测试边界
        (aMan, aExp, bMan, bExp) = setBounds(aMan, aExp, bMan, bExp);

        //将0的指数设置为-8192
        (aExp, bExp,) = zero_helper(aMan, aExp, bMan, bExp,0,0);

        emit Log("selected numbers", aMan, aExp, bMan, bExp,0,0);

        //开始计算
        packedFloat a = Float128.toPackedFloat(aMan, aExp);
        packedFloat b = Float128.toPackedFloat(bMan, bExp);

        // x+y == y + x
        packedFloat a_b = Float128.add(a, b);

        packedFloat b_a = Float128.add(b, a);

        emit result("a_b.", packedFloat.unwrap(a_b), "b_a.", packedFloat.unwrap(b_a));
        assert(Float128.eq(a_b, b_a));
    }

    // add(x,-y) = sub(x,y)
    function test_sub_add_equalitiy(int aMan, int aExp, int bMan, int bExp) public {
        //先定测试边界
        (aMan, aExp, bMan, bExp) = setBounds(aMan, aExp, bMan, bExp);

        //将0的指数设置为-8192
        (aExp, bExp,) = zero_helper(aMan, aExp, bMan, bExp,0,0);

        emit Log("selected numbers", aMan, aExp, bMan, bExp,0,0);

        //开始计算
        packedFloat a = Float128.toPackedFloat(aMan, aExp);
        packedFloat b = Float128.toPackedFloat(bMan, bExp);

        packedFloat neg_b = Float128.toPackedFloat(-bMan, bExp); 

        // add(x,-y) = sub(x,y)
        
        packedFloat add_result = Float128.add(a, neg_b);
        packedFloat sub_result = Float128.sub(a, b);

        emit result("add_result.", packedFloat.unwrap(add_result), "sub_result.", packedFloat.unwrap(sub_result));
        assert(Float128.eq(add_result, sub_result));
    }



    // (x * y) * z == x * (y * z)
    function test_exchange_mul(int aMan, int aExp, int bMan, int bExp, int cMan, int cExp) public {
        //先定测试边界
        (aMan, aExp, bMan, bExp) = setBounds(aMan, aExp, bMan, bExp);
        (cMan, cExp) = setBounds(cMan, cExp);

        //将0的指数设置为-8192
        (aExp, bExp, cExp) = zero_helper(aMan, aExp, bMan, bExp, cMan, cExp); //如果不用这个函数，会导致后期的乘法碰见潜在stack too deep 问题，最后一行永远不会达到

        emit Log("selected numbers", aMan, aExp, bMan, bExp, cMan, cExp);
        //开始计算
        packedFloat a = Float128.toPackedFloat(aMan, aExp);
        packedFloat b = Float128.toPackedFloat(bMan, bExp);
        packedFloat c = Float128.toPackedFloat(cMan, cExp);

        // (x * y) * z == x * (y * z)
        packedFloat a_b = Float128.mul(a, b);
        packedFloat a_b_c = Float128.mul(a_b, c);

        packedFloat b_c = Float128.mul(b, c);
        packedFloat b_c_a = Float128.mul(a, b_c);
        emit result("a_b_c.", packedFloat.unwrap(a_b_c), "b_c_a.", packedFloat.unwrap(b_c_a));

        assert(Float128.eq(a_b_c, b_c_a));
    }

    // Traces:
    // emit Log(«selected numbers», -1, 0, 1, -56, 1, 0) (/home/cohee/Projects/My-Auditing-Projects/2025-04-forte/test/audit/echidna.sol:71)
    // emit result(«a_b_c.», 57365990499224582412910503254121078371896747163757596332292310143568778887168, «b_c_a.», 0) (/home/cohee/Projects/My-Auditing-Projects/2025-04-forte/test/audit/echidna.sol:88)

    // test_exchange_mul(int256,int256,int256,int256,int256,int256): failed!💥
    //   Call sequence, shrinking 499598/1000000:
    //     BasicMath.test_exchange_mul(1,2,-56320631618675823624235,0,1775845759077883,241300190)

    // Traces:
    // emit Log(«selected numbers», 1, 2, -56320631618675823624235, 0, 1775845759077883, -20) (/home/cohee/Projects/My-Auditing-Projects/2025-04-forte/test/audit/echidna.sol:114)
    // emit result(«a_b_c.», 57541008375392451074725580993758167996248173069548282609146349157496748244992, «b_c_a.», 57541008375392451074725580993758167996248168069548282609146349157496748244992) (/home/cohee/Projects/My-Auditing-Projects/2025-04-forte/test/audit/echidna.sol:88)

    // test_exchange_add(int256,int256,int256,int256,int256,int256): failed!💥
    //   Call sequence:
    //     BasicMath.test_exchange_add(1,0,-1,0,-1,72)

    // Traces:
    // emit Log(«selected numbers», 1, 0, -1, 0, -1, 72) (/home/cohee/Projects/My-Auditing-Projects/2025-04-forte/test/audit/echidna.sol:68)
    // emit result(«a_b_c.», 57908512548111546402092575586849154356245784720098411352435643247365613158400, «b_c_a.», 57902345159852432864774242396846182682182474784510908876603156822560442679295) (/home/cohee/Projects/My-Auditing-Projects/2025-04-forte/test/audit/echidna.sol:87)

    // test_exchange_mul(int256,int256,int256,int256,int256,int256): failed!💥
    //   Call sequence:
    //     BasicMath.test_exchange_mul(1,1,56590547017219,0,1768519948645675415422529,-19)

    // Traces:
    // emit Log(«selected numbers», 1, 1, 56590547017219, 0, 1768519948645675415422529, -19) (/home/cohee/Projects/My-Auditing-Projects/2025-04-forte/test/audit/echidna.sol:110)
    // emit result(«a_b_c.», 57539241593084168800035605352231095909964691585651406990188227551295455625216, «b_c_a.», 57539241593084168800035605352231095909964690585651406990188227551295455625216) (/home/cohee/Projects/My-Auditing-Projects/2025-04-forte/test/audit/echidna.sol:87)

    // AssertionFailed(..): passing

    // Unique instructions: 2368
    // Unique codehashes: 1
    // Corpus size: 9
    // Seed: 1567789286206297310
    // Total calls: 43851
    
    
    ///找位数不会错
    function test_digits(uint256 addition) public  {
        require(
            !((addition <= MAX_M_DIGIT_NUMBER && addition >= MIN_M_DIGIT_NUMBER) || (addition <= MAX_L_DIGIT_NUMBER && addition >= MIN_L_DIGIT_NUMBER)),
            "addition is out of bounds"
        );

       uint256 log = findNumberOfDigits(addition);

        assert(addition/(10**log) == 0); //
    }


     function findNumberOfDigits(uint x) internal pure returns (uint log) {
        assembly {
            if gt(x, 0) {
                if gt(x, 9999999999999999999999999999999999999999999999999999999999999999) {//大于10^64 -1时，记录64位，并除以64
                    log := 64
                    x := div(x, 10000000000000000000000000000000000000000000000000000000000000000)//10^64，有65位数字 @audit 会不会有decimal loss？比如x=10^64? 或者x=10^64加1 
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
