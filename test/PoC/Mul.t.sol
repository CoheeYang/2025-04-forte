/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/Float128.sol";

contract mul is Test {
    using Float128 for packedFloat;
    event log(string,int,string,int);

    /// as long as a and b are too far away() from each other, the decimal loss would occur
    // this holds for a and b are m


        //1, 2, -56320631618675823624235, 0, 1775845759077883, -20

    int256 aMan = 50000000000000000000005;//23位数，大尾数49个0，比如这是合约中标的资产的奖励基数
    int256 aExp = 0;
    
    int256 bMan = 2000000000000003;//16位数,转大尾是56个0，这是在vault中存的shares占比
    int256 bExp = -20;

    int256 cMan = 1;
    int256 cExp = 2;//this makes

    //小尾*大尾，得到大尾，再乘大尾没问题
    //大尾*大尾，得到小尾，再乘小尾就有问题了（b_c_a），且最后乘的小尾指数减一就不会出现问题。
    //也就是说，问题定位应该是小小乘出大的地方有问题
    // "b_cMan", : 10001675480861318633128706354069129450 [-1e37], : "b_cExp", : -19)
    //  b_c实际值：100016754808613186331287063540691294505，39位数值+34个0（10^34），一共73位数，73位数在`mul`中除以10^35，导致精度丢失
    // "aMan", : 10000000000000000000000000000000000000 [1e37], : "aExp", : -35)
    //结果中72位掉了35位
        packedFloat a = Float128.toPackedFloat(aMan, aExp);
        packedFloat b = Float128.toPackedFloat(bMan, bExp);
        packedFloat c = Float128.toPackedFloat(cMan, cExp);
        //(a+b)+c
        packedFloat a_b = Float128.mul(a, b);
        packedFloat a_b_c = Float128.mul(a_b, c);
        
        //a+(b+c)
        packedFloat b_c = Float128.mul(b, c);
        packedFloat b_c_a = Float128.mul(a, b_c);

    function test_poc_mul() public {
        
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
