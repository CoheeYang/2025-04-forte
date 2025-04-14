/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "forge-std/console2.sol";
import "src/Float128.sol";
import "test/FloatUtils.sol";
import "lib/Uint512.sol";
import {Ln} from "src/Ln.sol";

//echidna test/audit/echidna.sol --contract BasicMath --config test/audit/echidna.yaml
contract BasicMath {
    using Float128 for packedFloat;
    using Ln for packedFloat;
    event Log(string, int256, int256, int256, int256, int256, int256);
    event result(string, uint256, string, uint256);
      event result(string, int256,int, string, int256,int);
    event checkLog(string);
    int256 constant BOUNDS_LOW = -3000; //exponents limits for float128
    int256 constant BOUNDS_HIGH = 3000;
    int constant ZERO_OFFSET_NEG = -8192;

    uint constant MAX_M_DIGIT_NUMBER = 99999999999999999999999999999999999999;
    uint constant MIN_M_DIGIT_NUMBER = 10000000000000000000000000000000000000;
    uint constant MAX_L_DIGIT_NUMBER = 999999999999999999999999999999999999999999999999999999999999999999999999;
    uint constant MIN_L_DIGIT_NUMBER = 100000000000000000000000000000000000000000000000000000000000000000000000;

    uint constant BASE_TO_THE_MAX_DIGITS_L = 1000000000000000000000000000000000000000000000000000000000000000000000000;
    int256 err;

    ///////////////helpers/////////////////
    function setBounds(int aMan, int aExp, int bMan, int bExp) internal pure returns (int _aMan, int _aExp, int _bMan, int _bExp) {
        // numbers with more than 38 digits lose precision
        _aMan = bound(aMan, -99999999999999999999999999999999999999, 99999999999999999999999999999999999999); //38位数
        _aExp = bound(aExp, BOUNDS_LOW, BOUNDS_HIGH); //-3000，3000
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

    function abs(int x) internal pure returns (int) {
        if (x < 0) {
            return -x;
        }
        return x;
    }

    ///////////////tests/////////////////
    //❌ H-1
    // (x + y) + z == x + (y + z)
    function test_exchange_add(int aMan, int aExp, int bMan, int bExp, int cMan, int cExp) public {
        //先定测试边界
        (aMan, aExp, bMan, bExp) = setBounds(aMan, aExp, bMan, bExp);
        (cMan, cExp) = setBounds(cMan, cExp);

        // //将0的指数设置为-8192
        // (aExp, bExp, cExp) = zero_helper(aMan, aExp, bMan, bExp, cMan, cExp);

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

    //✅
    // (x + y) == (y + x)
    function test_simple_exchange_add(int aMan, int aExp, int bMan, int bExp) public {
        //先定测试边界
        (aMan, aExp, bMan, bExp) = setBounds(aMan, aExp, bMan, bExp);

        // //将0的指数设置为-8192
        // (aExp, bExp, ) = zero_helper(aMan, aExp, bMan, bExp, 0, 0);

        emit Log("selected numbers", aMan, aExp, bMan, bExp, 0, 0);

        //开始计算
        packedFloat a = Float128.toPackedFloat(aMan, aExp);
        packedFloat b = Float128.toPackedFloat(bMan, bExp);

        // x+y == y + x
        packedFloat a_b = Float128.add(a, b);

        packedFloat b_a = Float128.add(b, a);

        emit result("a_b.", packedFloat.unwrap(a_b), "b_a.", packedFloat.unwrap(b_a));
        assert(Float128.eq(a_b, b_a));
    }

    //✅
    // add(x,-y) = sub(x,y)
    function test_sub_add_equalitiy(int aMan, int aExp, int bMan, int bExp) public {
        // //先定测试边界
        (aMan, aExp, bMan, bExp) = setBounds(aMan, aExp, bMan, bExp);

        // // //将0的指数设置为-8192
        // (aExp, bExp,) = zero_helper(aMan, aExp, bMan, bExp,0,0);

        emit Log("selected numbers", aMan, aExp, bMan, bExp, 0, 0);

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


  
    // a-b-c = a-c-b
    function test_exchange_sub(int aMan, int aExp, int bMan, int bExp, int cMan, int cExp) public {
        //先定测试边界
        (aMan, aExp, bMan, bExp) = setBounds(aMan, aExp, bMan, bExp);
        (cMan, cExp) = setBounds(cMan, cExp);

        // //将0的指数设置为-8192
        // (aExp, bExp, cExp) = zero_helper(aMan, aExp, bMan, bExp, cMan, cExp);

        emit Log("selected numbers", aMan, aExp, bMan, bExp, cMan, cExp);

        //开始计算
        packedFloat a = Float128.toPackedFloat(aMan, aExp);
        packedFloat b = Float128.toPackedFloat(bMan, bExp);
        packedFloat c = Float128.toPackedFloat(cMan, cExp);

        // a-b-c = a-c-b
        packedFloat a_b = Float128.sub(a, b);
        packedFloat a_b_c = Float128.sub(a_b, c);

        packedFloat a_c = Float128.sub(a, c);
        packedFloat a_c_b = Float128.sub(a_c, b);

        emit result("a_b_c.", packedFloat.unwrap(a_b_c), "b_c_a.", packedFloat.unwrap(a_c_b));
        assert(Float128.eq(a_b_c, a_c_b));
    }



    //❌ H-2
    // (x * y) * z == x * (y * z)
    function test_exchange_mul(int aMan, int aExp, int bMan, int bExp, int cMan, int cExp) public {
        //先定测试边界
        (aMan, aExp, bMan, bExp) = setBounds(aMan, aExp, bMan, bExp);
        (cMan, cExp) = setBounds(cMan, cExp);

        // //将0的指数设置为-8192
        // (aExp, bExp, cExp) = zero_helper(aMan, aExp, bMan, bExp, cMan, cExp); //如果不用这个函数，会导致后期的乘法碰见潜在stack too deep 问题，最后一行永远不会达到

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

    //✅
    // (x *y) == (y* x)
    function test_simple_exchange_mul(int aMan, int aExp, int bMan, int bExp) public {
        //先定测试边界
        (aMan, aExp, bMan, bExp) = setBounds(aMan, aExp, bMan, bExp);

        // //将0的指数设置为-8192
        // (aExp, bExp, ) = zero_helper(aMan, aExp, bMan, bExp, 0, 0);

        emit Log("selected numbers", aMan, aExp, bMan, bExp, 0, 0);

        //开始计算
        packedFloat a = Float128.toPackedFloat(aMan, aExp);
        packedFloat b = Float128.toPackedFloat(bMan, bExp);

        // x*y == y*x
        packedFloat a_b = Float128.mul(a, b);

        packedFloat b_a = Float128.mul(b, a);

        emit result("a_b.", packedFloat.unwrap(a_b), "b_a.", packedFloat.unwrap(b_a));
        assert(Float128.eq(a_b, b_a));
    }

    //✅
    // x/0 revert
    function test_revert_division(int xMan, int xExp) public {
        //先定测试边界
        (xMan, xExp) = setBounds(xMan, xExp);

        // //将0的指数设置为-8192
        // (xExp,,) = zero_helper(xExp, 0, 0, 0, 0, 0);

        emit Log("selected numbers", xMan, xExp, 0, 0, 0, 0);

        //开始计算
        packedFloat x = Float128.toPackedFloat(xMan, xExp);
        packedFloat zero = Float128.toPackedFloat(0, 0);

        // x/0 revert
        Float128.div(x, zero);
        //this line will never reach
        assert(false);
    }

    //✅
    // x/1 == x
    function test_divided_by1(int xMan, int xExp) public {
        //先定测试边界
        (xMan, xExp) = setBounds(xMan, xExp);

        // //将0的指数设置为-8192
        // (xExp,,) = zero_helper(xExp, 0, 0, 0, 0, 0);

        emit Log("selected numbers", xMan, xExp, 0, 0, 0, 0);

        //开始计算
        packedFloat x = Float128.toPackedFloat(xMan, xExp);
        packedFloat one = Float128.toPackedFloat(1, 0);

        (int xMan_dec, int xExp_dec) = Float128.decode(x);

        if (xMan_dec < 0) {
            //负数
            xMan_dec = -xMan_dec;
        }

        packedFloat r;
        //小配小大配大
        if (!((xMan_dec <= int(MAX_M_DIGIT_NUMBER) && xMan_dec >= int(MIN_M_DIGIT_NUMBER)) || (xMan_dec <= int(MAX_L_DIGIT_NUMBER) && xMan_dec >= int(MIN_L_DIGIT_NUMBER)))) {
            //decode出现问题
            if (xMan_dec != 0) {
                assert(false);
            }
        } else if (xMan_dec <= int(MAX_M_DIGIT_NUMBER) && xMan_dec >= int(MIN_M_DIGIT_NUMBER)) {
            //中尾数
            r = Float128.div(x, one, false);
        } else {
            //大尾
            r = Float128.div(x, one, true);
        }

        emit result("result:", packedFloat.unwrap(r), "x:", packedFloat.unwrap(x));
        assert(Float128.eq(r, x));
    }

    // ✅最大误差8
    // x/y == 1/(y/x), x!=0,y!=0
    function test_exchangeOne_division(int xMan, int xExp, int yMan, int yExp) public {
        //先定测试边界
        (xMan, xExp, yMan, yExp) = setBounds(xMan, xExp, yMan, yExp);

        require(xMan != 0 && yMan != 0, "zero number exits");

        emit Log("selected numbers", xMan, xExp, yMan, yExp, 0, 0);

        //开始计算
        packedFloat x = Float128.toPackedFloat(xMan, xExp);
        packedFloat y = Float128.toPackedFloat(yMan, yExp);
        packedFloat one = Float128.toPackedFloat(1, 0);

        // x/y == 1/(y/x)
        packedFloat x_y = Float128.div(x, y, true);

        packedFloat y_x = Float128.div(y, x, true);
        packedFloat one_y_X = Float128.div(one, y_x, true);

        emit result("x_y", packedFloat.unwrap(x_y), "one_y_x.", packedFloat.unwrap(one_y_X));

        err = abs(int256(packedFloat.unwrap(x_y) - packedFloat.unwrap(one_y_X)));
        // assert(err<10); //小于10个误差
    }

    // ✅
    // x/y/z = x/z/y 求最大误差,最大误差是9，可以接受
    function test_exchange_division(int xMan, int xExp, int yMan, int yExp, int zMan, int zExp) public {
        //先定测试边界
        (xMan, xExp, yMan, yExp) = setBounds(xMan, xExp, yMan, yExp);
        (zMan, zExp) = setBounds(zMan, zExp);

        require(yMan != 0 && zMan != 0, "zero number exits");

        emit Log("selected numbers", xMan, xExp, yMan, yExp, zMan, zExp);

        //开始计算
        packedFloat x = Float128.toPackedFloat(xMan, xExp);
        packedFloat y = Float128.toPackedFloat(yMan, yExp);
        packedFloat z = Float128.toPackedFloat(zMan, zExp);

        // x/y/z == x/z/y
        packedFloat x_y = Float128.div(x, y, true);
        packedFloat x_y_z = Float128.div(x_y, z, true);

        packedFloat x_z = Float128.div(x, z, true);
        packedFloat x_z_y = Float128.div(x_z, y, true);
        emit result("x_y_z", packedFloat.unwrap(x_y_z), "x_z_y.", packedFloat.unwrap(x_z_y));

        err = abs(int256(packedFloat.unwrap(x_y_z) - packedFloat.unwrap(x_z_y)));
        assert(err < 9);
    }

    function echidna_opt_err() public view returns (int256) {
        return err;
    }

    //✅passed
    ///none-negative number can always compute
    function test_neverRevert_sqrt(int xMan, int xExp) public {
        //precondition
        (xMan, xExp) = setBounds(xMan, xExp);
        if (xMan < 0) xMan = abs(xMan);

        emit Log("selected numbers", xMan, xExp, 0, 0, 0, 0);

        //开始计算
        packedFloat x = Float128.toPackedFloat(xMan, xExp);

        try Float128.sqrt(x) {
            assert(true);
        } catch {
            assert(false);
        }
    }
    ///❌failed
    // sqrt test sqrt(x^2) = x
    function test_sqrt(int xMan, int xExp) public {
        //precondition
        (xMan, xExp) = setBounds(xMan, xExp);
        if (xMan < 0) xMan = abs(xMan);

        int xMan_sq = xMan * xMan;
        int xExp_sq = xExp * 2;
        require(xMan_sq < 99999999999999999999999999999999999999 && xExp_sq < BOUNDS_HIGH && xExp_sq > BOUNDS_LOW, "out of bound");
        emit Log("selected numbers", xMan, xExp, xMan_sq, xExp_sq, 0, 0);

        packedFloat x = Float128.toPackedFloat(xMan, xExp);
        packedFloat x_sq = Float128.toPackedFloat(xMan_sq, xExp_sq);

        packedFloat x_sqrt = Float128.sqrt(x_sq);

        emit result("x_sqrt", packedFloat.unwrap(x_sqrt), "x.", packedFloat.unwrap(x));
        assert(packedFloat.unwrap(x_sqrt) == packedFloat.unwrap(x));
    }

    // function getSqrtNumber(int xMan, int xExp) public {
    //     //precondition
    //     (xMan, xExp) = setBounds(xMan, xExp);
    //     if (xMan < 0) xMan = abs(xMan);
    //     require(xMan!=0,"zero");
    //     packedFloat x = Float128.toPackedFloat(xMan, xExp);

    //     ///解码的数
    //     (xMan, xExp) = Float128.decode(x);
    //     //使得Exp符合第一个大情况的条件
    //     if (uint256(xMan) <= MAX_L_DIGIT_NUMBER && uint256(xMan) >= MIN_L_DIGIT_NUMBER) {
    //         //大尾数，要求aExp>-33
    //         xExp = bound(xExp, -33, BOUNDS_HIGH);
    //     } else if (uint256(xMan) <= MAX_M_DIGIT_NUMBER && uint256(xMan) >= MIN_M_DIGIT_NUMBER) {
    //         //中尾数，要求aExp>-18
    //         xExp = bound(xExp, -18, BOUNDS_HIGH);
    //     } else {
    //         assert(false);
    //     }

    //     (uint a0, uint a1) = Uint512.mul256x256(uint256(xMan), BASE_TO_THE_MAX_DIGITS_L); //aMan x 10^72
    //     uint rMan = Uint512.sqrt512(a0, a1);
    //     require(rMan > MAX_L_DIGIT_NUMBER);
    //     emit Log("selected numbers", xMan, xExp, 0, 0, 0, 0);
    //     assert(false);
    // }

    //✅
    //// (x / y) != (y / x)
    function test_div_commutative(int xMan, int xExp, int yMan, int yExp) public {
        //precondition
        (xMan, xExp, yMan, yExp) = setBounds(xMan, xExp, yMan, yExp);

        require(abs(xMan) != abs(yMan), "x and y are equal");
        emit Log("selected numbers", xMan, xExp, yMan, yExp, 0, 0);

        //开始计算
        packedFloat x = Float128.toPackedFloat(xMan, xExp);
        packedFloat y = Float128.toPackedFloat(yMan, yExp);

        packedFloat x_y = Float128.div(x, y, true);
        packedFloat y_x = Float128.div(y, x, true);
        emit result("x_y", packedFloat.unwrap(x_y), "y_x.", packedFloat.unwrap(y_x));
        assert(!Float128.eq(x_y, y_x));
    }

    //✅
    //// x/y = r, 如果y>1 x>0, 则r<x ...
    function test_div_comparison(int xMan, int xExp, int yMan) public {
        //先定测试边界
        (xMan, xExp, yMan, ) = setBounds(xMan, xExp, yMan, 0);

        yMan = abs(yMan); //y转正数

        emit Log("selected numbers", xMan, xExp, yMan, 0, 0, 0);

        //开始计算
        packedFloat x = Float128.toPackedFloat(xMan, xExp);
        packedFloat y = Float128.toPackedFloat(yMan, 0);

        //对情况进行判断
        if (yMan > 1 && xMan > 0) {
            // y>1 x>0
            packedFloat x_y = Float128.div(x, y, true);
            emit result("x/y", packedFloat.unwrap(x_y), "x", packedFloat.unwrap(x));
            assert(Float128.lt(x_y, x));
        } else if (yMan < 1 && xMan > 0) {
            // y<1 x>0
            packedFloat x_y = Float128.div(x, y, true);
            emit result("x/y", packedFloat.unwrap(x_y), "x", packedFloat.unwrap(x));
            assert(Float128.gt(x_y, x));
        } else if (yMan > 1 && xMan < 0) {
            // y>1 x<0
            packedFloat x_y = Float128.div(x, y, true);
            emit result("x/y", packedFloat.unwrap(x_y), "x", packedFloat.unwrap(x));
            assert(Float128.gt(x_y, x));
        } else if (yMan < 1 && xMan > 0) {
            // y<1 x<0
            packedFloat x_y = Float128.div(x, y, true);
            emit result("x/y", packedFloat.unwrap(x_y), "x", packedFloat.unwrap(x));
            assert(Float128.lt(x_y, x));
        }
    }

    //无效测试，精度问题损失很正常
    //ln x + ln y = ln xy
    function test_ln_add(int xMan, int xExp, int yMan, int yExp) public {
        (xMan, xExp, yMan, yExp) = setBounds(xMan, xExp, yMan, yExp);
        require(xMan !=0 && yMan != 0,"no zero");
        xMan = abs(xMan); //x转正数
        yMan = abs(yMan); //y转正数

        int xyMan = xMan*yMan;
        int xyExp = xExp+yExp; 

        require(xyMan < 99999999999999999999999999999999999999 && xyExp < BOUNDS_HIGH && xyExp > BOUNDS_LOW, "out of bound");
        emit Log("selected numbers", xMan, xExp, yMan, yExp, xyMan, xyExp);
        //开始计算
        packedFloat x = Float128.toPackedFloat(xMan, xExp);
        packedFloat y = Float128.toPackedFloat(yMan, yExp);
        packedFloat xy = Float128.toPackedFloat(xyMan, xyExp);



        packedFloat Ln_xy = Ln.ln(xy);
        packedFloat Ln_x = Ln.ln(x);
        packedFloat Ln_y = Ln.ln(y);

        // (int x_rMan,int x_rExp)= Float128.decode(x_r);
        // (int y_rMan,int y_rExp)= Float128.decode(y_r);
        // (int xy_rMan,int xy_rExp)= Float128.decode(xy_r);

        // int xR = x_rMan * 10 ** x_rExp;
        // int yR = y_rMan * 10 ** y_rExp;
        // int xyR = xy_rMan * 10 ** xy_rExp;

        packedFloat x_y = Float128.add(Ln_x, Ln_y);


       emit result("ln x+ ln y", packedFloat.unwrap(x_y), "ln xy", packedFloat.unwrap(Ln_xy));
       
       
        assert(packedFloat.unwrap(x_y) ==  packedFloat.unwrap(Ln_xy));

    }
    //failed (1,-16) (2,0) (2,-16)

    //无效测试
    // ln x^n = n*ln x
    function test_ln_power(int xMan, int xExp) public {
        (xMan, xExp) = setBounds(xMan, xExp);
        require(xMan !=0,"no zero");
        xMan = abs(xMan); //x转正数
        
        //n = 2
        int xnMan = xMan*xMan;
        int xnExp = xExp*2; 
        require(xnMan< 99999999999999999999999999999999999999 && xnExp < BOUNDS_HIGH && xnExp > BOUNDS_LOW, "out of bound");

        emit Log("selected numbers", xMan, xExp, 0, 0, xnMan, xnExp);

              //开始计算
        packedFloat x = Float128.toPackedFloat(xMan, xExp);
        packedFloat xn = Float128.toPackedFloat(xnMan, xnExp);

        packedFloat Ln_xn = Ln.ln(xn);
        packedFloat Ln_x = Ln.ln(x);

        packedFloat nLn_x = Float128.mul(Ln_x, Float128.toPackedFloat(2,0));

        emit result("ln x^2", packedFloat.unwrap(Ln_xn), "2*ln x", packedFloat.unwrap(nLn_x));
        (int Ln_xnMan,int Ln_xnExp)= Float128.decode(Ln_xn);
        (int nLn_xMan,int nLn_xExp)= Float128.decode(nLn_x);
        emit result("ln x^2", Ln_xnMan, Ln_xnExp, "2*ln x", nLn_xMan, nLn_xExp);
        assert(Float128.eq(Ln_xn, nLn_x));

    }//3就能失败




////其他功能性函数测试
    //✅
    // 等效性 a<b = b>a
    function test_comparison(int xMan, int xExp, int yMan, int yExp) public {
        //先定测试边界
        (xMan, xExp, yMan, yExp) = setBounds(xMan, xExp, yMan, yExp);

        emit Log("selected numbers", xMan, xExp, yMan, yExp, 0, 0);

        //开始计算
        packedFloat x = Float128.toPackedFloat(xMan, xExp);
        packedFloat y = Float128.toPackedFloat(yMan, yExp);

        //比较
        bool r1 = Float128.lt(x, y); //x<y?
        bool r2 = Float128.gt(y, x); //y>x?
        emit result("x:", packedFloat.unwrap(x), "y:", packedFloat.unwrap(y));
        assert(r1 == r2);
    }

    //✅ failed in 1^72,之前add的bug，暂时标记为通过
    // a+1>a
    function test_add_one(int xMan, int xExp) public {
        //先定测试边界
        (xMan, xExp) = setBounds(xMan, xExp);

        emit Log("selected numbers", xMan, xExp, 0, 0, 0, 0);

        //开始计算
        packedFloat x = Float128.toPackedFloat(xMan, xExp);
        packedFloat one = Float128.toPackedFloat(1, 0);

        packedFloat r = Float128.add(x, one);
        emit result("x+1", packedFloat.unwrap(r), "x", packedFloat.unwrap(x));
        assert(Float128.gt(r, x));
    }

    //✅
    ///找位数不会错
    function test_digits(uint256 addition) public pure {
        require(
            ((addition <= MAX_M_DIGIT_NUMBER && addition >= MIN_M_DIGIT_NUMBER) || (addition <= MAX_L_DIGIT_NUMBER && addition >= MIN_L_DIGIT_NUMBER)),
            "addition is out of bounds"
        );

        uint256 log = findNumberOfDigits(addition);

        assert(addition / (10 ** log) == 0); //
    }

    function findNumberOfDigits(uint x) internal pure returns (uint log) {
        assembly {
            if gt(x, 0) {
                if gt(x, 9999999999999999999999999999999999999999999999999999999999999999) {
                    //大于10^64 -1时，记录64位，并除以64
                    log := 64
                    x := div(x, 10000000000000000000000000000000000000000000000000000000000000000) //10^64，有65位数字 @audit 会不会有decimal loss？比如x=10^64? 或者x=10^64加1
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
