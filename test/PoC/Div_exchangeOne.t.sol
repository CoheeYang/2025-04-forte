/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/Float128.sol";

contract div_exchange is Test {
    using Float128 for packedFloat;
    event log(string,int,string,int);

//336736785007725, 0, -33977470318376327208959901260682, 0
    int256 aMan = 336736785007725;
    int256 aExp = 0;
    
    int256 bMan = 33977470318376327208959901260682;
    int256 bExp = 0;

    int256 oneMan = 1;
    int256 oneExp = 0;


        packedFloat a = Float128.toPackedFloat(aMan, aExp);
        packedFloat b = Float128.toPackedFloat(bMan, bExp);
        packedFloat one = Float128.toPackedFloat(oneMan, oneExp);
        
        packedFloat a_b = Float128.div(a, b,true);
        packedFloat b_a = Float128.div(b,a,true);
        packedFloat one_b_a =  Float128.div(one, b_a,true);


        


    function test_poc_div_exchangeOne() public {
        
        (int aMan_dec,int aExp_dec) = Float128.decode(a);
        (int bMan_dec,int bExp_dec) = Float128.decode(b);
        (int oneMan_dec,int oneExp_dec) = Float128.decode(one);

        (int a_bMan_dec,int a_bExp_dec) = Float128.decode(a_b);
        (int b_aMan_dec,int b_aExp_dec) = Float128.decode(b_a);
        (int one_b_aMan_dec,int one_b_aExp_dec) = Float128.decode(one_b_a);
        
        emit log("aMan",aMan_dec,"aExp",aExp_dec);
        emit log("bMan",bMan_dec,"bExp",bExp_dec);
        emit log("oneMan",oneMan_dec,"oneExp",oneExp_dec);

        emit log("b_aMan",b_aMan_dec,"b_cExp",b_aExp_dec);
        
        
        emit log("a_bMan",a_bMan_dec,"a_bExp",a_bExp_dec);
        emit log("one_b_a_Man",one_b_aMan_dec,"one_b_aExp",one_b_aExp_dec);


        assert(Float128.eq(a_b, one_b_a));  


    }



}
