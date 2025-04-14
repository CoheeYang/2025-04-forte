/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/Float128.sol";

contract add is Test {
    using Float128 for packedFloat;
    event log(string,int,string,int);

    /// as long as a and b are too far away() from each other, the decimal loss would occur
    // this holds for a and b are m

    int256 aMan = 1;
    int256 aExp = 10;

    int256 bMan = 1;
    int256 bExp = -28;
    
    int256 cMan = -1;
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
