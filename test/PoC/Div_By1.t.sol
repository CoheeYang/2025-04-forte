/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "src/Float128.sol";

contract divOne is Test {
    using Float128 for packedFloat;
    event log(string,int,string,int);



    int256 aMan = -1;
    int256 aExp = 0;
    

        packedFloat a = Float128.toPackedFloat(aMan, aExp);
        packedFloat one = Float128.toPackedFloat(1, 0);

       
        packedFloat r = Float128.div(a, one,true);


    function test_poc_divOne() public {
        
        (int aMan_dec,int aExp_dec) = Float128.decode(a);
        (int oneMan_dec,int oneExp_dec) = Float128.decode(one);
        (int rMan_dec,int rExp_dec) = Float128.decode(r);

        
        emit log("aMan",aMan_dec,"aExp",aExp_dec);
        emit log("oneMan",oneMan_dec,"oneExp",oneExp_dec);
        emit log("rMan",rMan_dec,"rExp",rExp_dec);



        assert(Float128.eq(a, r));  


    }



}
