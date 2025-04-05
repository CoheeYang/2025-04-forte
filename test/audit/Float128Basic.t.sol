/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/console2.sol";
import "src/Float128.sol";
import "test/FloatUtils.sol";
//forge test test/audit/Float128Basic.t.sol -vvvv
contract BasicMath is FloatUtils {
    int constant ZERO_OFFSET_NEG = -8192;
    event Log(string, int256, int256, int256, int256, int256, int256);

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



    // (x + y) + z == x + (y + z)
    function test_exchange_add(int aMan, int aExp, int bMan, int bExp, int cMan, int cExp) public  {
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

    
        console.log("a_b_c.", packedFloat.unwrap(a_b_c));
        console.log("b_c_a.", packedFloat.unwrap(b_c_a));
        assertTrue(Float128.eq(a_b_c, b_c_a));

    }


    // (x * y) * z == x * (y * z)
    function test_exchange_mul(int aMan, int aExp, int bMan, int bExp, int cMan, int cExp) public  {
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


    // (x * y) * z == x * (y * z)
        packedFloat a_b = Float128.mul(a, b);
        packedFloat a_b_c = Float128.mul(a_b, c);

        packedFloat b_c = Float128.mul(b, c);
        packedFloat b_c_a = Float128.mul(a, b_c);


        console.log("a_b_c.", packedFloat.unwrap(a_b_c));
        console.log("b_c_a.", packedFloat.unwrap(b_c_a));

        assertTrue(Float128.eq(a_b_c, b_c_a));

    }






}
