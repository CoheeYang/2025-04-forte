/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/Float128.sol";

contract sub is Test {
    using Float128 for packedFloat;
    event log(string,int,string,int);

    /// as long as a and b are too far away() from each other, the decimal loss would occur
    // this holds for `a` and `b` are m

    int256 aMan = 1;
    int256 aExp = 11;

    int256 bMan = 1;
    int256 bExp = -28;
    
    int256 cMan = 1;
    int256 cExp = 10;


        // a-b-c != a-c-b
        packedFloat a = Float128.toPackedFloat(aMan, aExp);
        packedFloat b = Float128.toPackedFloat(bMan, bExp);
        packedFloat c = Float128.toPackedFloat(cMan, cExp);
        //(a-b)-c
        packedFloat a_b = Float128.sub(a, b);
        packedFloat a_b_c = Float128.sub(a_b, c);
        
        //a-c-b
        packedFloat a_c = Float128.sub(a, c);
        packedFloat a_c_b = Float128.sub(a_c, b);

    function test_poc_sub() public {
        
        (int aMan_dec,int aExp_dec) = Float128.decode(a);
        (int bMan_dec,int bExp_dec) = Float128.decode(b);
        (int cMan_dec,int cExp_dec) = Float128.decode(c);
        (int a_bMan_dec,int a_bExp_dec) = Float128.decode(a_b);
        (int a_cMan_dec,int a_cExp_dec) = Float128.decode(a_c);
        (int a_b_cMan_dec,int a_b_cExp_dec) = Float128.decode(a_b_c);
        (int a_c_bMan_dec,int a_c_bExp_dec) = Float128.decode(a_c_b);
        
        emit log("aMan",aMan_dec,"aExp",aExp_dec);
        emit log("bMan",bMan_dec,"bExp",bExp_dec);
        emit log("cMan",cMan_dec,"cExp",cExp_dec);

        emit log("a_bMan",a_bMan_dec,"a_bExp",a_bExp_dec);
        emit log("a_cMan",a_cMan_dec,"a_cExp",a_cExp_dec);

        emit log("a_b_c_Man",a_b_cMan_dec,"a_b_cExp",a_b_cExp_dec);
        emit log("a_c_b_Man",a_c_bMan_dec,"a_c_bExp",a_c_bExp_dec);


        assert(Float128.eq(a_b_c, a_c_b));  


    }



}
